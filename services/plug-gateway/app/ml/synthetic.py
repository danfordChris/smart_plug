"""Synthetic per-appliance power signatures.

Bootstraps the training set for appliance-identification and per-type anomaly
models when little/no real telemetry exists yet. Each generator returns a power
window (numpy array). Determinism comes from a seeded numpy Generator.
"""
from __future__ import annotations

import numpy as np

from .features import extract_features, feature_vector

# Appliance type names mirror the Flutter ApplianceType enum.
APPLIANCE_TYPES = [
    "radio",
    "fridge",
    "heater",
    "airConditioner",
    "washer",
    "waterHeater",
    "light",
    "other",
]


def _noise(rng, n, scale):
    return rng.normal(0.0, scale, n)


def _radio(rng, n):
    base = rng.uniform(6, 12)
    x = base + _noise(rng, n, 0.6)
    return np.clip(x, 0, None)


def _fridge(rng, n):
    # Compressor duty cycle: high for part of a ~n/3 period, low baseline.
    period = rng.integers(max(6, n // 4), max(8, n // 2))
    on_len = int(period * rng.uniform(0.3, 0.5))
    peak = rng.uniform(90, 140)
    base = rng.uniform(1, 4)
    x = np.full(n, base)
    start = rng.integers(0, period)
    for s in range(-start, n, period):
        x[max(0, s):max(0, s) + on_len] = peak
    return np.clip(x[:n] + _noise(rng, n, 2.0), 0, None)


def _heater(rng, n):
    # Thermostat: big square swings between ~1500W and near 0.
    period = rng.integers(max(8, n // 4), max(10, n // 2))
    peak = rng.uniform(1200, 2000)
    x = np.zeros(n)
    on_len = int(period * rng.uniform(0.4, 0.7))
    for s in range(0, n, period):
        x[s:s + on_len] = peak
    return np.clip(x + _noise(rng, n, 20.0), 0, None)


def _air_conditioner(rng, n):
    period = rng.integers(max(8, n // 4), max(10, n // 2))
    peak = rng.uniform(700, 1300)
    base = rng.uniform(20, 60)  # fan baseline
    x = np.full(n, base)
    on_len = int(period * rng.uniform(0.4, 0.6))
    for s in range(0, n, period):
        x[s:s + on_len] = peak
    return np.clip(x + _noise(rng, n, 15.0), 0, None)


def _washer(rng, n):
    # Program phases: fill (low) -> heat (high) -> wash (med) -> spin (med-high).
    x = np.zeros(n)
    phases = [
        (rng.uniform(8, 20), 0.2),
        (rng.uniform(1500, 2200), 0.25),
        (rng.uniform(150, 400), 0.3),
        (rng.uniform(300, 700), 0.25),
    ]
    i = 0
    for level, frac in phases:
        ln = int(n * frac)
        x[i:i + ln] = level
        i += ln
    x[i:] = rng.uniform(2, 6)
    return np.clip(x + _noise(rng, n, 10.0), 0, None)


def _water_heater(rng, n):
    peak = rng.uniform(1800, 3000)
    x = np.zeros(n)
    on_len = int(n * rng.uniform(0.3, 0.6))
    start = rng.integers(0, max(1, n - on_len))
    x[start:start + on_len] = peak
    return np.clip(x + _noise(rng, n, 25.0), 0, None)


def _light(rng, n):
    on = rng.random() < 0.6
    level = rng.uniform(8, 60)
    x = np.full(n, level if on else 0.0)
    return np.clip(x + _noise(rng, n, 0.5), 0, None)


def _other(rng, n):
    level = rng.uniform(0, 40)
    x = np.full(n, level) + _noise(rng, n, level * 0.3 + 1)
    return np.clip(x, 0, None)


_GENERATORS = {
    "radio": _radio,
    "fridge": _fridge,
    "heater": _heater,
    "airConditioner": _air_conditioner,
    "washer": _washer,
    "waterHeater": _water_heater,
    "light": _light,
    "other": _other,
}


def synthesize(appliance_type: str, window: int = 120, rng=None) -> np.ndarray:
    rng = rng or np.random.default_rng()
    gen = _GENERATORS.get(appliance_type, _other)
    return gen(rng, window)


def make_dataset(per_type: int = 60, window: int = 120, seed: int = 7):
    """Returns (X, y): a feature matrix + appliance-type labels for the
    appliance-ID classifier, built from synthetic signatures."""
    rng = np.random.default_rng(seed)
    X, y = [], []
    for t in APPLIANCE_TYPES:
        for _ in range(per_type):
            powers = synthesize(t, window, rng).tolist()
            X.append(feature_vector(extract_features(powers)))
            y.append(t)
    return X, y


def normal_feature_matrix(appliance_type: str, count: int = 80, window: int = 120, seed: int = 11):
    """Feature matrix of healthy windows for one type — trains its anomaly gate."""
    rng = np.random.default_rng(seed)
    return [
        feature_vector(extract_features(synthesize(appliance_type, window, rng).tolist()))
        for _ in range(count)
    ]
