"""Diagnose one plug from its recent power window.

Combines the trained appliance classifier + per-type anomaly gate (when a model
bundle is present) with an evidence-based fault rule-map (always on). Degrades to
`model_version="heuristic-fallback"` when no bundle is loaded, so the feature
works before any training has run.
"""
from __future__ import annotations

import numpy as np

from . import explain
from .features import ON_THRESHOLD_W, extract_features, feature_vector


def _standby_band(powers):
    """2-cluster KMeans to detect a standby band (drawing > off-threshold but
    well below the active level for a meaningful share of the window)."""
    try:
        from sklearn.cluster import KMeans

        arr = np.array([p for p in powers if p is not None], dtype=float)
        if arr.size < 8 or (arr.max() - arr.min()) < 5:
            return None
        km = KMeans(n_clusters=2, n_init=3, random_state=0).fit(arr.reshape(-1, 1))
        centers = km.cluster_centers_.ravel()
        low_label = int(np.argmin(centers))
        low, high = float(centers.min()), float(centers.max())
        in_low = arr[km.labels_ == low_label]
        standby_pct = 100.0 * in_low.size / arr.size
        if ON_THRESHOLD_W < low < high * 0.5 and standby_pct > 20:
            return {"standby_w": low, "standby_pct": standby_pct}
    except Exception:
        return None
    return None


def diagnose(bundle, powers, states=None, appliance_type="", *, on_now=None) -> dict:
    feats = extract_features(powers, states)
    vec = feature_vector(feats)

    findings: list[dict] = []
    model_version = "heuristic-fallback"
    appliance_guess = ""
    confidence = 0.0
    anomaly_score = None

    if bundle:
        model_version = str(bundle.get("version", "1"))
        clf = bundle.get("appliance_clf")
        scaler = bundle.get("scaler")
        if clf is not None and scaler is not None:
            try:
                Xs = scaler.transform([vec])
                appliance_guess = str(clf.predict(Xs)[0])
                proba = clf.predict_proba(Xs)[0]
                confidence = float(np.max(proba))
            except Exception:
                pass
        t = appliance_type or appliance_guess
        anom = (bundle.get("anomaly") or {}).get(t)
        if anom is not None:
            try:
                anomaly_score = float(anom.decision_function([vec])[0])
                # Soft signal: per-type baselines are partly synthetic at cold
                # start, so a bare anomaly is informational — concrete faults
                # (stuck-on, no-draw, cost spike) carry the warning severity.
                if anom.predict([vec])[0] == -1:
                    findings.append({"code": "anomaly", "severity": "info", "evidence": {}})
            except Exception:
                pass

    t = appliance_type or appliance_guess
    mean = feats["mean"]
    mx = feats["max"]
    on_fraction = feats["on_fraction"]
    pwoff = feats["power_while_off"]
    spikiness = feats["spikiness"]
    cycle = feats["cycle_period"]

    # ── Evidence-based fault rule-map (runs with or without a model) ──────────
    if pwoff > 5:
        findings.append({"code": "stuck_on", "severity": "warning",
                         "evidence": {"power_while_off": pwoff}})
    if on_now and mean < ON_THRESHOLD_W:
        findings.append({"code": "no_draw", "severity": "warning", "evidence": {}})
    if spikiness > 1.5 and mx > 20:
        findings.append({"code": "power_spikes", "severity": "warning", "evidence": {}})
    if t in ("heater", "waterHeater") and on_fraction > 0.3 and mx < 300:
        findings.append({"code": "not_heating", "severity": "warning", "evidence": {"max": mx}})
    if t == "fridge" and on_fraction > 0.5 and cycle == 0 and feats["range"] < 10:
        findings.append({"code": "not_cycling", "severity": "warning", "evidence": {}})

    band = _standby_band(powers)
    if band:
        findings.append({"code": "standby_waste", "severity": "info", "evidence": band})

    if appliance_guess and appliance_type and appliance_guess != appliance_type and confidence > 0.6:
        findings.append({"code": "type_mismatch", "severity": "info",
                         "evidence": {"guess": appliance_guess}})

    if not findings:
        if on_fraction < 0.05:
            findings.append({"code": "idle", "severity": "info", "evidence": {}})
        else:
            findings.append({"code": "healthy", "severity": "ok", "evidence": {}})

    result = {
        "findings": findings,
        "appliance_guess": appliance_guess,
        "confidence": confidence,
        "anomaly_score": anomaly_score,
        "model_version": model_version,
        "features": feats,
    }
    return explain.finalize(result)
