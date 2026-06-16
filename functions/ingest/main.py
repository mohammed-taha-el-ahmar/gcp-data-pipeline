"""
GCP Cloud Function (Gen2, HTTP): ingest

Invoked on a schedule by Cloud Scheduler. Fetches data via shared.ingest
and writes the raw record to Cloud Storage under raw/.

Note: when packaging for deployment, copy shared/ alongside this file (or
include it via a shared build step) so `from shared.ingest import ...`
resolves.
"""

import json
import os

import functions_framework
from google.cloud import storage

from shared.ingest import fetch_data, raw_object_key, to_raw_record

storage_client = storage.Client()
BUCKET = os.environ["DATA_LAKE_BUCKET"]


@functions_framework.http
def ingest(request):
    raw = fetch_data()
    record = to_raw_record(raw)
    key = raw_object_key()

    bucket = storage_client.bucket(BUCKET)
    blob = bucket.blob(key)
    blob.upload_from_string(json.dumps(record), content_type="application/json")

    return {"key": key}, 200
