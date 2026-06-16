# GCP implementation

> Part of a multi-cloud data engineering pattern — see `PORTFOLIO.md` in the
> companion repos for the cross-cloud comparison. Same `shared/` ingest +
> transform logic as `aws-data-pipeline`, `azure-data-pipeline`, and
> `k8s-airflow-data-platform`.

`API -> Cloud Storage -> BigQuery -> Dashboard`

## Components

- **Cloud Storage** (`google_storage_bucket.data_lake`) — landing zone.
  The ingest function writes raw JSON under `raw/`.
- **Cloud Function: ingest** (`functions/ingest/`) — HTTP-triggered,
  called on a schedule by Cloud Scheduler. Calls `shared.ingest.fetch_data`.
- **Cloud Function: transform** (`functions/transform/`) — triggered by
  Cloud Storage object-finalize events (via Eventarc). Calls
  `shared.transform.transform_record` and streams the row into BigQuery.
- **BigQuery** — `weather_pipeline.weather_observations` table.
- **Front end** (`frontend/index.html`) — static dashboard placeholder.

## Setup

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # set your GCP project id
terraform init
terraform apply
```

## TODOs to take this from scaffold to working pipeline

- [ ] Package `functions/ingest` and `functions/transform` (each needs its
      own copy of `shared/`, or reference it via a shared layer / build
      step) and upload the zips to `google_storage_bucket.function_source`
      — `main.tf` currently points at `ingest.zip` / `transform.zip` as
      placeholders.
- [ ] Grant the Cloud Functions service account `roles/bigquery.dataEditor`
      and `roles/storage.objectViewer` on the data lake bucket.
- [ ] Build a small endpoint (Cloud Function or Cloud Run) that returns the
      latest row from BigQuery as JSON, and wire it into
      `frontend/index.html`. Alternatively, point `frontend/index.html` at
      an embedded Looker Studio report built on the BigQuery table.

## Teardown

```bash
cd terraform
terraform destroy
```
