"""Train the classic ML bundle: an appliance-ID classifier + per-type anomaly
gates, from synthetic signatures plus any real labelled windows supplied by the
caller (mined recorder data / live telemetry, weak-labelled by DeviceConfig).

DB-agnostic: the caller passes already-extracted feature vectors so this stays
unit-testable on synthetic data alone.
"""
from __future__ import annotations

from sklearn.ensemble import IsolationForest, RandomForestClassifier
from sklearn.preprocessing import StandardScaler

from . import registry, synthetic
from .synthetic import APPLIANCE_TYPES


def train(
    models_dir: str,
    real_samples=None,   # list[(feature_vector, label)]
    real_normals=None,   # dict[type] -> list[feature_vector] (healthy windows)
    per_type: int = 60,
    window: int = 120,
    seed: int = 7,
) -> dict:
    X, y = synthetic.make_dataset(per_type=per_type, window=window, seed=seed)
    n_real = 0
    if real_samples:
        for vec, label in real_samples:
            if label in APPLIANCE_TYPES:
                X.append(list(vec))
                y.append(label)
                n_real += 1

    scaler = StandardScaler().fit(X)
    clf = RandomForestClassifier(n_estimators=120, random_state=seed)
    clf.fit(scaler.transform(X), y)

    anomaly = {}
    for i, t in enumerate(APPLIANCE_TYPES):
        normals = synthetic.normal_feature_matrix(t, count=80, window=window, seed=seed + i)
        if real_normals and real_normals.get(t):
            normals = normals + [list(v) for v in real_normals[t]]
        iso = IsolationForest(n_estimators=100, contamination=0.05, random_state=seed)
        iso.fit(normals)
        anomaly[t] = iso

    bundle = {
        "version": "1",
        "appliance_clf": clf,
        "scaler": scaler,
        "anomaly": anomaly,
    }
    summary = {
        "types": APPLIANCE_TYPES,
        "n_samples": len(X),
        "n_real_samples": n_real,
        "window": window,
    }
    registry.save_bundle(models_dir, bundle, summary)
    return summary
