"""Glue: build a full diagnosis for one entity from stored telemetry, the model
bundle, the cost baseline, and a templated explanation. Shared by the diagnosis
router (on demand) and the monitor loop (alerting)."""
from __future__ import annotations

from . import cost, dataset, explain, infer

WINDOW = 120
MIN_SAMPLES = 12


def diagnose_entity(engine, settings, bundle, entity_id: str,
                    appliance_type: str = "", display_name: str = "") -> dict:
    display_name = display_name or entity_id.split(".", 1)[-1]
    powers, states = dataset.recent_window(engine, entity_id, WINDOW)
    valid = [p for p in powers if p is not None]

    if len(valid) < MIN_SAMPLES:
        result = {
            "findings": [{"code": "collecting", "severity": "ok", "evidence": {}}],
            "appliance_guess": "",
            "confidence": 0.0,
            "anomaly_score": None,
            "model_version": "insufficient-data",
            "features": {},
        }
    else:
        on_now = bool(states) and states[-1] == "on"
        result = infer.diagnose(bundle, powers, states, appliance_type, on_now=on_now)
        c = cost.cost_anomaly(engine, entity_id, settings.tariff_per_kwh)
        if c:
            result["findings"].append(c)

    explain.finalize(result, display_name=display_name,
                     currency=settings.currency_symbol)
    return result
