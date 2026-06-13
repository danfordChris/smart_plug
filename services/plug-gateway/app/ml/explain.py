"""Turn structured diagnosis findings into a natural-language explanation and a
short status label. Classic ML emits the findings; prose is templated here (no
LLM), so explanations stay grounded in the model's evidence.
"""
from __future__ import annotations

SEVERITY_ORDER = {"ok": 0, "info": 1, "warning": 2, "critical": 3}
STATUS_BY_SEVERITY = {
    "ok": "Healthy",
    "info": "Notice",
    "warning": "Needs attention",
    "critical": "Faulty",
}


def _w(x) -> str:
    try:
        return f"{float(x):.0f} W"
    except Exception:
        return "0 W"


def worst_severity(findings) -> str:
    sev = "ok"
    for f in findings:
        if SEVERITY_ORDER.get(f.get("severity", "ok"), 0) > SEVERITY_ORDER[sev]:
            sev = f.get("severity", "ok")
    return sev


def status_label(severity: str) -> str:
    return STATUS_BY_SEVERITY.get(severity, "Healthy")


def render_finding(f: dict, *, currency: str = "TSh") -> str:
    code = f.get("code", "")
    ev = f.get("evidence", {}) or {}
    if code == "collecting":
        return (
            "Still collecting data — the diagnosis will sharpen as more telemetry "
            "is gathered."
        )
    if code == "healthy":
        return "Running normally — telemetry looks healthy."
    if code == "idle":
        return "Mostly off — no issues detected."
    if code == "stuck_on":
        return (
            f"Drawing about {_w(ev.get('power_while_off', 0))} while switched "
            "off — possible stuck relay or a load left connected."
        )
    if code == "no_draw":
        return (
            "Switched on but drawing almost no power — it may be unplugged, "
            "failed, or not actually running."
        )
    if code == "power_spikes":
        return "Power is unusually spiky — an intermittent load or loose connection."
    if code == "not_heating":
        return (
            f"Peaks at only {_w(ev.get('max', 0))}, far below a heating element — "
            "it may not be heating."
        )
    if code == "not_cycling":
        return (
            "Expected to cycle on and off but it is holding steady — check the "
            "thermostat or compressor."
        )
    if code == "standby_waste":
        return (
            f"Spends ~{ev.get('standby_pct', 0):.0f}% of the time on standby "
            f"(~{_w(ev.get('standby_w', 0))}) — a schedule or auto-off would save power."
        )
    if code == "anomaly":
        return "Behaviour differs from this appliance's normal pattern."
    if code == "type_mismatch":
        return f"Its signature looks more like a {ev.get('guess', 'different appliance')}."
    if code == "cost_spike":
        return (
            f"Today's projected cost is about {currency} {ev.get('today_cost', 0):,.0f}, "
            f"~{ev.get('ratio', 1):.1f}× its usual {currency} {ev.get('baseline_cost', 0):,.0f}."
        )
    return code or "No details."


def compose(result: dict, *, display_name: str = "This plug", currency: str = "TSh") -> str:
    findings = result.get("findings", [])
    if not findings:
        return f"{display_name} is running normally."
    return " ".join(render_finding(f, currency=currency) for f in findings)


def finalize(result: dict, *, display_name: str = "This plug", currency: str = "TSh") -> dict:
    """(Re)compute severity, status label and explanation from current findings.
    Idempotent — the router calls it again after appending cost findings."""
    findings = result.get("findings", [])
    sev = worst_severity(findings)
    result["severity"] = sev
    result["status_label"] = status_label(sev)
    result["explanation"] = compose(result, display_name=display_name, currency=currency)
    return result
