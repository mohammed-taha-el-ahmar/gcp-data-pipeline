output "data_lake_bucket" {
  value = google_storage_bucket.data_lake.name
}

output "bigquery_table" {
  value = "${google_bigquery_dataset.warehouse.dataset_id}.${google_bigquery_table.observations.table_id}"
}

output "ingest_function_url" {
  value = google_cloudfunctions2_function.ingest.url
}
