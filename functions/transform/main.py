"""
GCP Cloud Function (Gen2, CloudEvent): transform

Triggered by Cloud Storage object-finalize events on the data lake bucket.
Reads the raw JSON, flattens it via shared.transform, and streams the row
into BigQuery.

Note: when packaging for deployment, copy shared/ alongside this file.
"""

import json
import os

import functions_framework
from google.cloud import bigquery, storage

from shared.transform import transform_record

storage_client = storage.Client()
bq_client = bigquery.Client()

DATASET = os.environ["BQ_DATASET"]
TABLE = os.environ["BQ_TABLE"]


@functions_framework.cloud_event
def transform(cloud_event):
    data = cloud_event.data
    bucket_name = data["bucket"]
    object_name = data["name"]

    if not object_name.startswith("raw/"):
        return

    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(object_name)
    raw = json.loads(blob.download_as_text())

    row = transform_record(raw)

    table_ref = f"{bq_client.project}.{DATASET}.{TABLE}"
    errors = bq_client.insert_rows_json(table_ref, [row])
    if errors:
        raise RuntimeError(f"BigQuery insert errors: {errors}")

    print("Inserted row:", row)
