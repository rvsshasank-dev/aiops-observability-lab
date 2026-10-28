locals {
  state_bucket_name = "${var.project_id}-tfstate"

  # APIs needed by Phase 1 and by the first workload phase.
  services = toset([
    "artifactregistry.googleapis.com",
    "billingbudgets.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
  ])
}

data "google_project" "this" {
  project_id = var.project_id
}


resource "google_project_service" "enabled" {
  for_each = local.services

  project = var.project_id
  service = each.value

  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_storage_bucket" "tfstate" {
  name     = local.state_bucket_name
  project  = var.project_id
  location = var.state_bucket_location

  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  # Keep the current state plus a bounded history of previous versions.
  lifecycle_rule {
    condition {
      num_newer_versions = 20
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }

  labels = var.labels

  depends_on = [google_project_service.enabled]
}

resource "google_billing_budget" "monthly" {
  billing_account = var.billing_account
  display_name    = "AIOps Observability Lab monthly budget"

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.budget_amount_usd)
    }
  }

  budget_filter {
    # The Billing Budget API returns the project number, not the project ID.
    projects = ["projects/${data.google_project.this.number}"]
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.8
  }
  threshold_rules {
    threshold_percent = 1.0
  }
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  depends_on = [google_project_service.enabled]
}
