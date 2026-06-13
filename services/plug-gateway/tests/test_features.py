"""Pure feature-engineering + synthetic-signature tests."""
import numpy as np

from app.ml.features import FEATURE_NAMES, extract_features, feature_vector
from app.ml import synthetic


def test_empty_window_is_all_zero():
    f = extract_features([])
    assert set(f) == set(FEATURE_NAMES)
    assert all(v == 0.0 for v in f.values())
    assert len(feature_vector(f)) == len(FEATURE_NAMES)


def test_vector_order_and_length():
    f = extract_features([1, 2, 3, 4, 5])
    assert len(feature_vector(f)) == len(FEATURE_NAMES)
    assert feature_vector(f)[FEATURE_NAMES.index("max")] == 5.0


def test_steady_load_low_spikiness_high_on_fraction():
    powers = [8.0 + 0.1 * (i % 3) for i in range(60)]
    f = extract_features(powers)
    assert f["on_fraction"] == 1.0
    assert f["spikiness"] < 0.1
    assert f["peak_to_base"] < 2.0


def test_cyclic_load_detects_period_and_high_peak_to_base():
    # Square wave: 8 high, 8 low, repeated.
    powers = ([120.0] * 8 + [2.0] * 8) * 6
    f = extract_features(powers)
    assert f["cycle_period"] > 0
    assert f["peak_to_base"] > 10
    assert 0.0 < f["duty_cycle"] < 1.0


def test_power_while_off_flags_stuck_draw():
    powers = [40.0] * 10
    states = ["off"] * 10
    f = extract_features(powers, states)
    assert f["power_while_off"] == 40.0


def test_synthetic_types_are_separable():
    radio = extract_features(synthetic.synthesize("radio", 120, np.random.default_rng(1)).tolist())
    heater = extract_features(synthetic.synthesize("heater", 120, np.random.default_rng(1)).tolist())
    # Heater pulls far more power than a radio.
    assert heater["max"] > radio["max"] * 10


def test_make_dataset_shapes():
    X, y = synthetic.make_dataset(per_type=5, window=80, seed=3)
    assert len(X) == len(y) == 5 * len(synthetic.APPLIANCE_TYPES)
    assert all(len(row) == len(FEATURE_NAMES) for row in X)
    assert set(y) == set(synthetic.APPLIANCE_TYPES)
