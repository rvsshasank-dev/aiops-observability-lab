output "project_id" {
  description = "Project that owns the lab."
  value       = var.project_id
}

output "state_bucket" {
  description = "GCS bucket that holds every Terraform state file."
  value       = google_storage_bucket.tfstate.name
}

output "state_bucket_url" {
  description = "gs:// URL for the state bucket."
  value       = google_storage_bucket.tfstate.url
}

output "budget_name" {
  description = "Monthly budget display name."
  value       = google_billing_budget.monthly.display_name
}

output "enabled_services" {
  description = "APIs enabled by bootstrap."
  value       = sort([for s in google_project_service.enabled : s.service])
}
