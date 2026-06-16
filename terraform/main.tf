# ---------------------------------------------------------------------------
# Landing zone + function source bucket
# ---------------------------------------------------------------------------
resource "google_storage_bucket" "data_lake" {
  name          = "${var.project_name}-data-lake-${var.gcp_project_id}"
  location      = var.gcp_region
  force_destroy = true
}

resource "google_storage_bucket" "function_source" {
  name          = "${var.project_name}-function-source-${var.gcp_project_id}"
  location      = var.gcp_region
  force_destroy = true
}

# ---------------------------------------------------------------------------
# BigQuery — warehouse
# ---------------------------------------------------------------------------
resource "google_bigquery_dataset" "warehouse" {
  dataset_id = "weather_pipeline"
  location   = var.gcp_region
}

resource "google_bigquery_table" "observations" {
  dataset_id = google_bigquery_dataset.warehouse.dataset_id
  table_id   = "weather_observations"

  schema = jsonencode([
    { name = "ingested_at", type = "TIMESTAMP" },
    { name = "latitude", type = "FLOAT" },
    { name = "longitude", type = "FLOAT" },
    { name = "temperature_c", type = "FLOAT" },
    { name = "wind_speed_kmh", type = "FLOAT" },
    { name = "humidity_pct", type = "FLOAT" },
  ])
}

# ---------------------------------------------------------------------------
# Cloud Function: ingest — HTTP, invoked on a schedule
# TODO: upload functions/ingest as ingest.zip to function_source bucket
# before applying (see README "Setup").
# ---------------------------------------------------------------------------
resource "google_cloudfunctions2_function" "ingest" {
  name     = "${var.project_name}-ingest"
  location = var.gcp_region

  build_config {
    runtime     = "python312"
    entry_point = "ingest"
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = "ingest.zip"
      }
    }
  }

  service_config {
    environment_variables = {
      DATA_LAKE_BUCKET = google_storage_bucket.data_lake.name
    }
  }
}

resource "google_cloud_scheduler_job" "ingest_schedule" {
  name      = "${var.project_name}-ingest-schedule"
  schedule  = "0 * * * *" # hourly
  time_zone = "Etc/UTC"

  http_target {
    uri         = google_cloudfunctions2_function.ingest.url
    http_method = "POST"
  }
}

# ---------------------------------------------------------------------------
# Cloud Function: transform — triggered by Cloud Storage object finalize
# TODO: upload functions/transform as transform.zip to function_source
# bucket before applying.
# ---------------------------------------------------------------------------
resource "google_cloudfunctions2_function" "transform" {
  name     = "${var.project_name}-transform"
  location = var.gcp_region

  build_config {
    runtime     = "python312"
    entry_point = "transform"
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = "transform.zip"
      }
    }
  }

  service_config {
    environment_variables = {
      BQ_DATASET = google_bigquery_dataset.warehouse.dataset_id
      BQ_TABLE   = google_bigquery_table.observations.table_id
    }
  }

  event_trigger {
    trigger_region = var.gcp_region
    event_type     = "google.cloud.storage.object.v1.finalized"
    event_filters {
      attribute = "bucket"
      value     = google_storage_bucket.data_lake.name
    }
  }
}

# TODO: front end — either point frontend/index.html at an embedded Looker
# Studio report on google_bigquery_table.observations, or deploy a small
# Cloud Run service that queries BigQuery and returns JSON.
