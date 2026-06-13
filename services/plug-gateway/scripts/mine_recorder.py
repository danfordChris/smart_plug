#!/usr/bin/env python3
"""Mine the Home Assistant recorder DB (READ-ONLY) for historical plug power
series and backfill the gateway's PlugTelemetry table — giving the diagnosis
models real data to train on from day one.

The recorder is SQLite by default (`home-assistant_v2.db`) or MariaDB/Postgres.
We only ever SELECT from it. The gateway's own DB is written to.

Usage (on the Pi):
  python scripts/mine_recorder.py \
      --recorder /home/smart/homeassistant/home-assistant_v2.db \
      --gateway-db /data/plug_gateway.db \
      --days 30

  # MariaDB recorder:
  python scripts/mine_recorder.py --recorder "mysql+pymysql://user:pw@host/homeassistant" ...

Power entities are taken from the gateway's DeviceConfig.power_entity_id rows
(plus any passed via --entity). HA versions differ slightly; the script guards
the modern `states`+`states_meta` schema and falls back to legacy `states.entity_id`.
"""
from __future__ import annotations

import argparse
import sys
from datetime import datetime, timedelta, timezone

from sqlalchemy import create_engine, text
from sqlmodel import Session, select

# Allow running as `python scripts/mine_recorder.py` from the service root.
sys.path.insert(0, ".")
from app.models import DeviceConfig, PlugTelemetry  # noqa: E402


def _recorder_url(path: str) -> str:
    if "://" in path:
        return path  # already a SQLAlchemy URL (MariaDB/Postgres)
    # SQLite read-only via URI (the recorder is mounted :ro, so a normal
    # read-write open would fail). The path portion must start with `file:`.
    return f"sqlite:///file:{path}?mode=ro&uri=true"


def _power_entities(gateway_engine, extra):
    ents = set(extra or [])
    with Session(gateway_engine) as s:
        for cfg in s.exec(select(DeviceConfig)).all():
            if cfg.power_entity_id:
                ents.add(cfg.power_entity_id)
    return sorted(ents)


def _entity_owner(gateway_engine):
    """Map power_entity_id -> (user_id, switch entity_id) from DeviceConfig."""
    owner = {}
    with Session(gateway_engine) as s:
        for cfg in s.exec(select(DeviceConfig)).all():
            if cfg.power_entity_id:
                owner[cfg.power_entity_id] = (cfg.created_by, cfg.entity_id)
    return owner


def _derive_switch(power_entity: str) -> str:
    """SonoffLAN convention: sensor.<base>_power -> switch.<base>_1. Used when no
    DeviceConfig maps the sensor to its switch yet, so mined history still lands
    under the switch entity the app/diagnosis queries."""
    name = power_entity.split(".", 1)[-1]
    if name.endswith("_power"):
        name = name[: -len("_power")]
    return f"switch.{name}_1"


def _has_states_meta(conn) -> bool:
    try:
        conn.execute(text("SELECT 1 FROM states_meta LIMIT 1"))
        return True
    except Exception:
        return False


def _fetch_series(conn, power_entity: str, since_ts: float):
    """Return [(timestamp, state_str)] for a power sensor, newest schema first."""
    if _has_states_meta(conn):
        q = text(
            "SELECT s.last_updated_ts, s.state "
            "FROM states s JOIN states_meta m ON s.metadata_id = m.metadata_id "
            "WHERE m.entity_id = :eid AND s.last_updated_ts >= :since "
            "ORDER BY s.last_updated_ts"
        )
    else:
        q = text(
            "SELECT last_updated_ts, state FROM states "
            "WHERE entity_id = :eid AND last_updated_ts >= :since "
            "ORDER BY last_updated_ts"
        )
    for row in conn.execute(q, {"eid": power_entity, "since": since_ts}):
        yield row[0], row[1]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--recorder", required=True, help="HA recorder DB path or SQLAlchemy URL")
    ap.add_argument("--gateway-db", default="/data/plug_gateway.db")
    ap.add_argument("--days", type=int, default=30)
    ap.add_argument("--entity", action="append", default=[], help="extra power entity_id")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    gw_engine = create_engine(f"sqlite:///{args.gateway_db}", connect_args={"check_same_thread": False})
    rec_engine = create_engine(_recorder_url(args.recorder))

    power_entities = _power_entities(gw_engine, args.entity)
    owner = _entity_owner(gw_engine)
    if not power_entities:
        print("No power entities found (configure plugs first, or pass --entity).")
        return 1

    since = (datetime.now(timezone.utc) - timedelta(days=args.days)).timestamp()
    total = 0
    with rec_engine.connect() as conn:  # read-only
        for pe in power_entities:
            user_id, switch_eid = owner.get(pe, (1, _derive_switch(pe)))
            rows = list(_fetch_series(conn, pe, since))
            print(f"{pe}: {len(rows)} samples")
            if args.dry_run or not rows:
                total += len(rows)
                continue
            with Session(gw_engine) as gs:
                for ts, state in rows:
                    try:
                        power = float(state)
                    except (TypeError, ValueError):
                        continue
                    gs.add(PlugTelemetry(
                        user_id=user_id,
                        entity_id=switch_eid,
                        power_w=power,
                        state="",  # recorder power sensor has no on/off; inferred at training
                        recorded_at=datetime.fromtimestamp(ts, tz=timezone.utc).replace(tzinfo=None),
                    ))
                gs.commit()
            total += len(rows)

    print(f"{'Would import' if args.dry_run else 'Imported'} {total} samples from the recorder.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
