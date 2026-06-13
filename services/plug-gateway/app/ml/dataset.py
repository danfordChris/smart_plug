"""Build training/inference data from the gateway's own telemetry DB.

Weak labels come from `DeviceConfig.appliance_type` (the user's own label for
each plug). The HA-recorder miner backfills `PlugTelemetry` so this has history
to slice on day one.
"""
from __future__ import annotations

from collections import defaultdict

from sqlmodel import Session, select

from ..models import DeviceConfig, PlugTelemetry
from .features import extract_features, feature_vector


def recent_window(engine, entity_id: str, window: int = 120):
    """Most recent `window` telemetry samples for an entity (chronological)."""
    with Session(engine) as s:
        rows = s.exec(
            select(PlugTelemetry)
            .where(PlugTelemetry.entity_id == entity_id)
            .order_by(PlugTelemetry.recorded_at.desc())
            .limit(window)
        ).all()
    rows = list(reversed(rows))
    return [r.power_w for r in rows], [r.state for r in rows]


def build_real_training_data(engine, window: int = 120, max_per_entity: int = 4000):
    """Slice each labelled plug's telemetry into windows → (feature, label)
    samples + per-type 'normal' matrices (the plug's own behaviour)."""
    real_samples = []
    real_normals = defaultdict(list)
    with Session(engine) as s:
        configs = s.exec(
            select(DeviceConfig).where(DeviceConfig.appliance_type != "")
        ).all()
        for cfg in configs:
            rows = s.exec(
                select(PlugTelemetry)
                .where(PlugTelemetry.entity_id == cfg.entity_id)
                .order_by(PlugTelemetry.recorded_at)
                .limit(max_per_entity)
            ).all()
            powers = [r.power_w for r in rows]
            states = [r.state for r in rows]
            for i in range(0, len(powers) - window + 1, window):
                w = powers[i:i + window]
                st = states[i:i + window]
                if sum(1 for p in w if p is not None) < window * 0.5:
                    continue
                vec = feature_vector(extract_features(w, st))
                real_samples.append((vec, cfg.appliance_type))
                real_normals[cfg.appliance_type].append(vec)
    return real_samples, dict(real_normals)
