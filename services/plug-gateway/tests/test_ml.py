"""Train/infer/registry smoke + fault rule-map."""
import numpy as np

from app.ml import registry, synthetic, train as train_mod
from app.ml.infer import diagnose


def test_train_persists_and_loads(tmp_path):
    summary = train_mod.train(str(tmp_path), per_type=20, window=120, seed=5)
    assert set(synthetic.APPLIANCE_TYPES) == set(summary["types"])
    bundle = registry.load_bundle(str(tmp_path))
    assert bundle is not None
    assert bundle.get("appliance_clf") is not None
    assert set(bundle.get("anomaly", {})) == set(synthetic.APPLIANCE_TYPES)


def test_trained_model_classifies_and_diagnoses(tmp_path):
    train_mod.train(str(tmp_path), per_type=40, window=120, seed=5)
    bundle = registry.load_bundle(str(tmp_path))
    heater = synthetic.synthesize("heater", 120, np.random.default_rng(99)).tolist()
    res = diagnose(bundle, heater, appliance_type="heater", on_now=True)
    assert res["appliance_guess"] in synthetic.APPLIANCE_TYPES
    assert 0.0 <= res["confidence"] <= 1.0
    assert res["model_version"] != "heuristic-fallback"
    assert "explanation" in res and res["explanation"]


def test_fallback_without_bundle_is_healthy_for_steady_load():
    powers = [8.0 + 0.1 * (i % 2) for i in range(60)]
    res = diagnose(None, powers, states=["on"] * 60, appliance_type="radio", on_now=True)
    assert res["model_version"] == "heuristic-fallback"
    assert res["status_label"] == "Healthy"


def test_stuck_on_detected():
    res = diagnose(None, [40.0] * 12, states=["off"] * 12, appliance_type="radio")
    codes = {f["code"] for f in res["findings"]}
    assert "stuck_on" in codes
    assert res["severity"] == "warning"


def test_no_draw_when_on():
    res = diagnose(None, [0.0] * 12, states=["on"] * 12, appliance_type="radio", on_now=True)
    codes = {f["code"] for f in res["findings"]}
    assert "no_draw" in codes


def test_not_heating_for_heater():
    # Heater on most of the window but only ~50 W → not heating.
    res = diagnose(None, [50.0] * 20, states=["on"] * 20, appliance_type="heater", on_now=True)
    codes = {f["code"] for f in res["findings"]}
    assert "not_heating" in codes


def test_standby_waste_detected():
    powers = [5.0] * 70 + [100.0] * 30
    res = diagnose(None, powers, states=["on"] * 100, appliance_type="other")
    codes = {f["code"] for f in res["findings"]}
    assert "standby_waste" in codes


def test_registry_refuses_version_mismatch(tmp_path):
    import joblib
    train_mod.train(str(tmp_path), per_type=10, window=80, seed=1)
    path = tmp_path / registry.MODEL_FILE
    bundle = joblib.load(path)
    bundle["sklearn_version"] = "0.0.0-fake"
    joblib.dump(bundle, path)
    assert registry.load_bundle(str(tmp_path)) is None
