output "data_lake_bucket" {
  value = google_storage_bucket.data_lake.name
}

output "function_source_bucket" {
  value = google_storage_bucket.function_source.name
}

output "bigquery_table" {
  value = "${google_bigquery_dataset.warehouse.dataset_id}.${google_bigquery_table.observations.table_id}"
}

output "ingest_function_url" {
  value = google_cloudfunctions2_function.ingest.url
}

output "latest_function_url" {
  value = google_cloudfunctions2_function.latest.url
}

output "frontend_url" {
  value = google_cloud_run_v2_service.frontend.uri
}
