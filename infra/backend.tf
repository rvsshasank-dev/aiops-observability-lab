terraform {
  # Partial GCS backend. Create the bucket with infra/bootstrap first, then:
  #   cp backend.hcl.example backend.hcl   # fill in the bucket name
  #   terraform init -backend-config=backend.hcl
  backend "gcs" {}
}
