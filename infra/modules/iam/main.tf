locals {
  # Kubernetes namespaces and names used by WIF bindings. The bindings do not
  # require the namespace or ServiceAccount to exist yet.
  tempo_ksa     = "observability/tempo"
  loki_ksa      = "observability/loki"
  wif_smoke_ksa = "default/wif-smoke-test"
}

# --- Node identity ---------------------------------------------------------

resource "google_service_account" "node" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-node"
  display_name = "GKE node service account"
  description  = "Least-privilege identity for the general GKE node pool."
}

resource "google_project_iam_member" "node_default" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.node.email}"
}

resource "google_project_iam_member" "node_artifact_registry" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.node.email}"
}

# --- Workload identities ---------------------------------------------------

resource "google_service_account" "tempo" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-tempo"
  display_name = "Tempo object storage"
  description  = "Writes trace blocks to the Tempo GCS bucket."
}

resource "google_service_account" "loki" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-loki"
  display_name = "Loki object storage"
  description  = "Writes log chunks to the Loki GCS bucket."
}

resource "google_service_account" "wif_smoke" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-wif-smoke"
  display_name = "Workload Identity smoke test"
  description  = "Read-only identity used to prove WIF, with no access to telemetry buckets."
}

# --- Bucket-level permissions ---------------------------------------------

resource "google_storage_bucket_iam_member" "tempo_object_admin" {
  bucket = var.tempo_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.tempo.email}"
}

resource "google_storage_bucket_iam_member" "loki_object_admin" {
  bucket = var.loki_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.loki.email}"
}

resource "google_storage_bucket_iam_member" "wif_smoke_object_viewer" {
  bucket = var.wif_smoke_bucket
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.wif_smoke.email}"
}

# --- Workload Identity Federation bindings ---------------------------------

resource "google_service_account_iam_member" "tempo_workload_identity" {
  service_account_id = google_service_account.tempo.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${local.tempo_ksa}]"
}

resource "google_service_account_iam_member" "loki_workload_identity" {
  service_account_id = google_service_account.loki.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${local.loki_ksa}]"
}

resource "google_service_account_iam_member" "wif_smoke_workload_identity" {
  service_account_id = google_service_account.wif_smoke.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${local.wif_smoke_ksa}]"
}
