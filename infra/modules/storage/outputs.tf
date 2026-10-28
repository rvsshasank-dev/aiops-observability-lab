output "bucket_names" {
  description = "Map of logical bucket name to GCS bucket name."
  value       = { for key, bucket in google_storage_bucket.this : key => bucket.name }
}

output "tempo_bucket" {
  description = "GCS bucket for Tempo."
  value       = google_storage_bucket.this["tempo"].name
}

output "loki_bucket" {
  description = "GCS bucket for Loki."
  value       = google_storage_bucket.this["loki"].name
}

output "wif_smoke_bucket" {
  description = "GCS bucket used by the Workload Identity smoke test."
  value       = google_storage_bucket.this["wif-smoke"].name
}
