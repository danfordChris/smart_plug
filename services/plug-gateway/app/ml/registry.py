"""Persist / load the trained diagnosis model bundle (joblib) + a JSON manifest.

Artifacts live in `settings.ml_models_dir` (the mounted /data volume on the Pi,
so they survive container recreation). On load we refuse a bundle whose
scikit-learn version differs from the running one and fall back to heuristics.
"""
from __future__ import annotations

import json
import os

import joblib
import sklearn

MODEL_FILE = "diagnosis.joblib"
MANIFEST_FILE = "manifest.json"


def save_bundle(models_dir: str, bundle: dict, summary: dict | None = None) -> dict:
    os.makedirs(models_dir, exist_ok=True)
    bundle = dict(bundle)
    bundle["sklearn_version"] = sklearn.__version__
    joblib.dump(bundle, os.path.join(models_dir, MODEL_FILE))
    manifest = {
        "sklearn_version": sklearn.__version__,
        "version": bundle.get("version", "1"),
        **(summary or {}),
    }
    with open(os.path.join(models_dir, MANIFEST_FILE), "w") as f:
        json.dump(manifest, f, default=str)
    return manifest


def load_bundle(models_dir: str):
    path = os.path.join(models_dir, MODEL_FILE)
    if not os.path.isfile(path):
        return None
    try:
        bundle = joblib.load(path)
    except Exception:
        return None
    # Refuse-and-fallback on version skew (pickled estimators aren't portable).
    if bundle.get("sklearn_version") != sklearn.__version__:
        return None
    return bundle


def read_manifest(models_dir: str) -> dict | None:
    path = os.path.join(models_dir, MANIFEST_FILE)
    if not os.path.isfile(path):
        return None
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return None
