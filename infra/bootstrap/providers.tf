provider "google" {
  project = var.project_id

  # billingbudgets and some other APIs require an explicit quota project when
  # Terraform authenticates with user Application Default Credentials.
  billing_project       = var.project_id
  user_project_override = true
}
