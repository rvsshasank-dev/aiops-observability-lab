terraform {
  # Partial GCS backend. The state bucket is created once by
  # scripts/setup/bootstrap-state.sh, then imported so Terraform owns it.
  # Supply bucket and prefix with -backend-config=backend.hcl.
  backend "gcs" {}
}
