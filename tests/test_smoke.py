"""
Smoke tests — fast contract-level checks that can run in CI without
GCP credentials.

These exercise the full ingest → transform path using only the shared
library (no cloud SDK stubs required).
"""

import json

import pytest

from shared.ingest import fetch_data, raw_object_key, to_raw_record
from shared.transform import transform_record


@pytest.mark.smoke
def test_ingest_transform_roundtrip():
    """End-to-end: fetch live data → wrap → transform → valid row."""
    payload = fetch_data()
    record = to_raw_record(payload)

    # Ensure record is JSON-serializable (what gets written to GCS)
    blob = json.dumps(record)
    rehydrated = json.loads(blob)

    row = transform_record(rehydrated)

    # Row must have all warehouse columns
    expected_keys = {
        "ingested_at",
        "latitude",
        "longitude",
        "temperature_c",
        "wind_speed_kmh",
        "humidity_pct",
    }
    assert set(row.keys()) == expected_keys

    # Sanity-check types / ranges
    assert isinstance(row["temperature_c"], (int, float))
    assert -80 <= row["temperature_c"] <= 60
    assert isinstance(row["wind_speed_kmh"], (int, float))
    assert row["wind_speed_kmh"] >= 0


@pytest.mark.smoke
def test_raw_object_key_is_date_partitioned():
    key = raw_object_key()
    parts = key.split("/")
    assert parts[0] == "raw"
    assert parts[1].startswith("year=")
    assert parts[2].startswith("month=")
    assert parts[3].startswith("day=")


@pytest.mark.smoke
def test_packaging_script_importable():
    """Ensures the packaging script is at least syntactically valid."""
    import scripts.package_functions as pkg  # noqa: F401

    assert hasattr(pkg, "package_function")
    assert hasattr(pkg, "FUNCTION_NAMES")
    assert "ingest" in pkg.FUNCTION_NAMES
    assert "transform" in pkg.FUNCTION_NAMES
    assert "latest" in pkg.FUNCTION_NAMES
