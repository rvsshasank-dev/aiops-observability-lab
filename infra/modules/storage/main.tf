locals {
  buckets = {
    tempo = {
      description    = "Tempo trace blocks"
      retention_days = var.telemetry_retention_days
    }
    loki = {
      description    = "Loki log chunks"
      retention_days = var.telemetry_retention_days
    }
    wif-smoke = {
      description    = "Workload Identity smoke test"
      retention_days = 1
    }
  }
}

resource "google_storage_bucket" "this" {
  for_each = local.buckets

  # The project ID makes the bucket name globally unique.
  name     = "${var.project_id}-${each.key}"
  project  = var.project_id
  location = var.region

  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = var.force_destroy

  labels = merge(var.labels, {
    component = each.key
  })

  lifecycle_rule {
    condition {
      age = each.value.retention_days
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age = 1
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }

  # This is an experiment environment; soft delete would only add cost.
  soft_delete_policy {
    retention_duration_seconds = 0
  }
}
