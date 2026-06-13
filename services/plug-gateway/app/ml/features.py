"""Feature engineering from a plug's power time-series window.

Pure, dependency-light (numpy only) and unit-tested. Every model in this package
consumes `feature_vector(extract_features(...))` so train and inference share one
definition of the feature space. FEATURE_NAMES fixes the column order.
"""
from __future__ import annotations

import numpy as np

# Below this many watts a plug is treated as effectively off / standby-ish.
ON_THRESHOLD_W = 2.0

FEATURE_NAMES = [
    "mean",
    "std",
    "min",
    "max",
    "median",
    "p10",
    "p90",
    "range",
    "on_fraction",
    "duty_cycle",
    "peak_to_base",
    "cycle_period",
    "slope",
    "spikiness",
    "power_while_off",
    "zero_run_frac",
]


def _safe(x: float) -> float:
    if x is None or not np.isfinite(x):
        return 0.0
    return float(x)


def _dominant_period(x: np.ndarray) -> float:
    """First autocorrelation peak (in samples) — captures cyclic appliances
    like a fridge compressor. 0 when no clear cycle."""
    if x.size < 6:
        return 0.0
    xc = x - x.mean()
    if np.allclose(xc, 0):
        return 0.0
    ac = np.correlate(xc, xc, mode="full")[xc.size - 1:]
    if ac[0] == 0:
        return 0.0
    ac = ac / ac[0]
    for i in range(2, ac.size - 1):
        if ac[i] > ac[i - 1] and ac[i] >= ac[i + 1] and ac[i] > 0.2:
            return float(i)
    return 0.0


def extract_features(powers, states=None) -> dict:
    """Compute the diagnosis feature dict from a power window (list of floats,
    Nones allowed) and an optional matching list of HA state strings."""
    arr = np.array([p for p in powers if p is not None], dtype=float)
    if arr.size == 0:
        return {k: 0.0 for k in FEATURE_NAMES}

    mean = arr.mean()
    std = arr.std()
    pmin = arr.min()
    pmax = arr.max()
    median = float(np.median(arr))
    p10 = float(np.percentile(arr, 10))
    p90 = float(np.percentile(arr, 90))
    base = max(p10, 0.0)
    on_mask = arr > ON_THRESHOLD_W
    on_fraction = float(on_mask.mean())
    # Duty cycle: share of samples above the midpoint between base and peak.
    midpoint = base + 0.5 * (pmax - base)
    duty_cycle = float((arr > midpoint).mean()) if pmax > base else 0.0
    peak_to_base = float(pmax / base) if base > 1e-6 else float(pmax)
    cycle_period = _dominant_period(arr)
    # Slope per sample (trend) via least squares.
    if arr.size >= 2:
        slope = float(np.polyfit(np.arange(arr.size), arr, 1)[0])
    else:
        slope = 0.0
    # Spikiness: mean absolute sample-to-sample change, normalised by mean.
    if arr.size >= 2:
        diffs = np.abs(np.diff(arr))
        spikiness = float(diffs.mean() / mean) if mean > 1e-6 else float(diffs.mean())
    else:
        spikiness = 0.0
    # Fraction of samples at ~zero power.
    zero_run_frac = float((arr <= ON_THRESHOLD_W).mean())

    # Power drawn while HA reports the switch "off" (stuck/leak detector).
    power_while_off = 0.0
    if states is not None:
        offs = [
            p
            for p, s in zip(powers, states)
            if p is not None and s == "off"
        ]
        if offs:
            power_while_off = float(np.mean(offs))

    feats = {
        "mean": mean,
        "std": std,
        "min": pmin,
        "max": pmax,
        "median": median,
        "p10": p10,
        "p90": p90,
        "range": pmax - pmin,
        "on_fraction": on_fraction,
        "duty_cycle": duty_cycle,
        "peak_to_base": peak_to_base,
        "cycle_period": cycle_period,
        "slope": slope,
        "spikiness": spikiness,
        "power_while_off": power_while_off,
        "zero_run_frac": zero_run_frac,
    }
    return {k: _safe(v) for k, v in feats.items()}


def feature_vector(features: dict) -> list:
    """Flatten a feature dict into FEATURE_NAMES order for sklearn."""
    return [_safe(features.get(name, 0.0)) for name in FEATURE_NAMES]
