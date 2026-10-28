provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone

  # Keep quota/billing attribution on the lab project when authenticating with
  # user Application Default Credentials.
  billing_project       = var.project_id
  user_project_override = true
}
