"""Telemetry logging + rollup/retention."""
from datetime import datetime, timedelta

from sqlmodel import Session, select

from app.config import Settings
from app.models import DeviceConfig, PlugTelemetry, PlugTelemetryRollup
from app.monitor import _log_telemetry, _floor_bucket, maintain_telemetry


def _engine(client):
    return client.app.state.engine


def test_log_telemetry_inserts_one_row_per_plug(client):
    engine = _engine(client)
    configs = [
        DeviceConfig(created_by=1, entity_id="switch.radio", power_entity_id="sensor.radio_power"),
        DeviceConfig(created_by=1, entity_id="switch.fan", power_entity_id="sensor.fan_power"),
    ]
    states = {
        "switch.radio": {"entity_id": "switch.radio", "state": "on"},
        "sensor.radio_power": {"entity_id": "sensor.radio_power", "state": "8.2"},
        "switch.fan": {"entity_id": "switch.fan", "state": "off"},
        "sensor.fan_power": {"entity_id": "sensor.fan_power", "state": "0"},
    }
    _log_telemetry(engine, configs, states, datetime(2026, 6, 9, 10, 0, 0))

    with Session(engine) as s:
        rows = s.exec(select(PlugTelemetry)).all()
    by_entity = {r.entity_id: r for r in rows}
    assert by_entity["switch.radio"].power_w == 8.2
    assert by_entity["switch.radio"].state == "on"
    assert by_entity["switch.fan"].power_w == 0.0
    assert by_entity["switch.fan"].state == "off"


def test_floor_bucket():
    assert _floor_bucket(datetime(2026, 6, 9, 10, 7, 31), 5) == datetime(2026, 6, 9, 10, 5, 0)
    assert _floor_bucket(datetime(2026, 6, 9, 10, 4, 59), 5) == datetime(2026, 6, 9, 10, 0, 0)


def test_maintain_rolls_up_and_prunes(client):
    engine = _engine(client)
    now = datetime(2026, 6, 9, 12, 0, 0)
    old = now - timedelta(days=10)  # older than default 7-day retention
    with Session(engine) as s:
        # 3 raw samples in the same 5-min bucket: 2 on, 1 off.
        for i, (p, st) in enumerate([(10.0, "on"), (12.0, "on"), (0.0, "off")]):
            s.add(PlugTelemetry(
                user_id=1, entity_id="switch.radio", power_w=p, state=st,
                recorded_at=old + timedelta(seconds=i * 30),
            ))
        s.commit()

    settings = Settings(telemetry_retention_days=7, rollup_minutes=5, rollup_retention_days=180)
    maintain_telemetry(engine, settings, now)

    with Session(engine) as s:
        raw = s.exec(select(PlugTelemetry)).all()
        rollups = s.exec(select(PlugTelemetryRollup)).all()
    assert raw == []  # consumed
    assert len(rollups) == 1
    r = rollups[0]
    assert r.samples == 3
    assert r.power_max == 12.0
    assert r.power_min == 0.0
    assert abs(r.on_fraction - (2 / 3)) < 1e-6
