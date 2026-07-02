# ---------------------------------------------------------------------------
# Landing zone + function source bucket
# ---------------------------------------------------------------------------
resource "google_storage_bucket" "data_lake" {
  name                        = "${var.project_name}-datalake-${var.gcp_project_id}"
  location                    = var.gcp_region
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "function_source" {
  name                        = "${var.project_name}-fn-src-${var.gcp_project_id}"
  location                    = var.gcp_region
  force_destroy               = true
  uniform_bucket_level_access = true
}

# ---------------------------------------------------------------------------
# BigQuery — warehouse
# ---------------------------------------------------------------------------
resource "google_bigquery_dataset" "warehouse" {
  dataset_id = "weather_pipeline"
  location   = var.gcp_region
}

resource "google_bigquery_table" "observations" {
  dataset_id          = google_bigquery_dataset.warehouse.dataset_id
  table_id            = "weather_observations"
  deletion_protection = false

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

# ---------------------------------------------------------------------------
# Cloud Function: latest — returns most recent BigQuery row as JSON
# ---------------------------------------------------------------------------
resource "google_cloudfunctions2_function" "latest" {
  name     = "${var.project_name}-latest"
  location = var.gcp_region

  build_config {
    runtime     = "python312"
    entry_point = "latest"
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = "latest.zip"
      }
    }
  }

  service_config {
    environment_variables = {
      BQ_DATASET = google_bigquery_dataset.warehouse.dataset_id
      BQ_TABLE   = google_bigquery_table.observations.table_id
    }
  }
}

# Allow unauthenticated access to the latest endpoint (public dashboard)
resource "google_cloud_run_service_iam_member" "latest_invoker" {
  location = var.gcp_region
  service  = google_cloudfunctions2_function.latest.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ---------------------------------------------------------------------------
# IAM — grant service account permissions for Cloud Functions
# ---------------------------------------------------------------------------
data "google_project" "current" {}

resource "google_project_iam_member" "functions_bq_editor" {
  project = var.gcp_project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_iam_member" "functions_bq_job_user" {
  project = var.gcp_project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_iam_member" "functions_storage_viewer" {
  project = var.gcp_project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

# Eventarc: compute SA needs eventReceiver for GCS-triggered functions
resource "google_project_iam_member" "eventarc_receiver" {
  project = var.gcp_project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

# GCS service agent needs pubsub.publisher to emit object notifications
resource "google_project_iam_member" "gcs_pubsub_publisher" {
  project = var.gcp_project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.current.number}@gs-project-accounts.iam.gserviceaccount.com"
}

# Eventarc needs run.invoker on transform so it can deliver events
resource "google_cloud_run_service_iam_member" "transform_invoker" {
  location = var.gcp_region
  service  = google_cloudfunctions2_function.transform.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

# ---------------------------------------------------------------------------
# Cloud Run: frontend — static dashboard served via nginx container
# ---------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "frontend" {
  name     = "${var.project_name}-frontend"
  location = var.gcp_region

  template {
    containers {
      image = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/${var.project_name}-repo/frontend:latest"

      ports {
        container_port = 8080
      }

      env {
        name  = "LATEST_API_URL"
        value = google_cloudfunctions2_function.latest.url
      }
    }
  }
}

# Allow unauthenticated access to the frontend
resource "google_cloud_run_v2_service_iam_member" "frontend_invoker" {
  name     = google_cloud_run_v2_service.frontend.name
  location = var.gcp_region
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Artifact Registry repo for frontend container image
resource "google_artifact_registry_repository" "repo" {
  location      = var.gcp_region
  repository_id = "${var.project_name}-repo"
  format        = "DOCKER"
}
