"""
GCP Cloud Function (Gen2, HTTP): latest

Returns the most recently ingested weather row from BigQuery as JSON.
Used by frontend/index.html.
"""

import json
import os
from typing import Any

import functions_framework
from google.cloud import bigquery

bq_client = bigquery.Client()

DATASET = os.environ["BQ_DATASET"]
TABLE = os.environ["BQ_TABLE"]


def build_latest_query(project_id: str, dataset: str, table: str) -> str:
    return (
        "SELECT ingested_at, latitude, longitude, temperature_c, "
        "wind_speed_kmh, humidity_pct "
        f"FROM `{project_id}.{dataset}.{table}` "
        "ORDER BY ingested_at DESC "
        "LIMIT 1"
    )


def _cors_headers() -> dict[str, str]:
    return {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET,OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type",
    }


@functions_framework.http
def latest(request):
    if request.method == "OPTIONS":
        return ("", 204, _cors_headers())

    query = build_latest_query(bq_client.project, DATASET, TABLE)
    rows = list(bq_client.query(query).result())

    if not rows:
        return (
            json.dumps({"error": "No observations found"}),
            404,
            {**_cors_headers(), "Content-Type": "application/json"},
        )

    row = rows[0]
    payload: dict[str, Any] = {
        "ingested_at": row["ingested_at"].isoformat(),
        "latitude": row["latitude"],
        "longitude": row["longitude"],
        "temperature_c": row["temperature_c"],
        "wind_speed_kmh": row["wind_speed_kmh"],
        "humidity_pct": row["humidity_pct"],
    }

    return (
        json.dumps(payload),
        200,
        {**_cors_headers(), "Content-Type": "application/json"},
    )
