output "node_service_account_email" {
  description = "Node pool service account email."
  value       = google_service_account.node.email
}

output "tempo_service_account_email" {
  description = "Tempo GSA email."
  value       = google_service_account.tempo.email
}

output "loki_service_account_email" {
  description = "Loki GSA email."
  value       = google_service_account.loki.email
}

output "wif_smoke_service_account_email" {
  description = "Workload Identity smoke test GSA email."
  value       = google_service_account.wif_smoke.email
}

output "workload_identity_bindings" {
  description = "Kubernetes service accounts bound through WIF."
  value = {
    tempo     = local.tempo_ksa
    loki      = local.loki_ksa
    wif_smoke = local.wif_smoke_ksa
  }
}
