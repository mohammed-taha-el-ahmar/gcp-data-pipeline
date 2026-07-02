"""Unit tests for shared ingest + transform logic."""

import json

import pytest

from shared.ingest import raw_object_key, to_raw_record
from shared.transform import transform_record

# ---------------------------------------------------------------------------
# shared.ingest
# ---------------------------------------------------------------------------


class TestRawObjectKey:
    def test_starts_with_prefix(self):
        key = raw_object_key("raw")
        assert key.startswith("raw/year=")

    def test_custom_prefix(self):
        key = raw_object_key("custom")
        assert key.startswith("custom/year=")

    def test_ends_with_json(self):
        key = raw_object_key()
        assert key.endswith(".json")


class TestToRawRecord:
    def test_wraps_payload(self):
        payload = {"latitude": 48.85, "longitude": 2.35}
        record = to_raw_record(payload)
        assert record["source"] == "open-meteo"
        assert record["payload"] == payload
        assert "ingested_at" in record

    def test_serializable(self):
        record = to_raw_record({"key": "value"})
        assert json.dumps(record)  # should not raise


# ---------------------------------------------------------------------------
# shared.transform
# ---------------------------------------------------------------------------


VALID_RAW = {
    "ingested_at": "2026-06-30T12:00:00+00:00",
    "source": "open-meteo",
    "payload": {
        "latitude": 48.8566,
        "longitude": 2.3522,
        "current": {
            "temperature_2m": 22.5,
            "wind_speed_10m": 15.3,
            "relative_humidity_2m": 61,
        },
    },
}


class TestTransformRecord:
    def test_flattens_correctly(self):
        row = transform_record(VALID_RAW)
        assert row["temperature_c"] == 22.5
        assert row["wind_speed_kmh"] == 15.3
        assert row["humidity_pct"] == 61
        assert row["latitude"] == 48.8566
        assert row["longitude"] == 2.3522
        assert row["ingested_at"] == VALID_RAW["ingested_at"]

    def test_missing_current_returns_nones(self):
        raw = {
            "ingested_at": "2026-06-30T12:00:00+00:00",
            "source": "open-meteo",
            "payload": {"latitude": 48.85, "longitude": 2.35},
        }
        row = transform_record(raw)
        assert row["temperature_c"] is None
        assert row["wind_speed_kmh"] is None
        assert row["humidity_pct"] is None

    def test_missing_ingested_at_raises(self):
        with pytest.raises(ValueError, match="ingested_at"):
            transform_record({"payload": {}})

    def test_missing_payload_raises(self):
        with pytest.raises(ValueError, match="payload"):
            transform_record({"ingested_at": "2026-01-01T00:00:00Z"})

    def test_non_dict_payload_raises(self):
        with pytest.raises(ValueError, match="payload must be a JSON object"):
            transform_record({"ingested_at": "2026-01-01T00:00:00Z", "payload": "bad"})
