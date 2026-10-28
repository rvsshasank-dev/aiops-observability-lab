output "project_id" {
  description = "Project that owns the lab."
  value       = var.project_id
}

output "state_bucket" {
  description = "GCS bucket holding this root's state (prefix terraform/lab)."
  value       = "${var.project_id}-tfstate"
}

output "network_name" {
  description = "VPC name."
  value       = module.network.network_name
}

output "subnet_name" {
  description = "Node subnet name."
  value       = module.network.subnet_name
}

output "cluster_name" {
  description = "GKE cluster name."
  value       = module.gke.cluster_name
}

output "cluster_zone" {
  description = "Zone of the zonal GKE cluster."
  value       = module.gke.location
}

output "kubectl_config_command" {
  description = "Command that writes the cluster credentials into kubeconfig."
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --zone ${module.gke.location} --project ${var.project_id}"
}

output "tempo_bucket" {
  description = "GCS bucket for Tempo trace storage."
  value       = module.storage.tempo_bucket
}

output "loki_bucket" {
  description = "GCS bucket for Loki log storage."
  value       = module.storage.loki_bucket
}

output "wif_smoke_bucket" {
  description = "Bucket used only by the Workload Identity smoke test."
  value       = module.storage.wif_smoke_bucket
}

output "service_accounts" {
  description = "Project-owned Google service accounts."
  value = {
    node      = module.iam.node_service_account_email
    tempo     = module.iam.tempo_service_account_email
    loki      = module.iam.loki_service_account_email
    wif_smoke = module.iam.wif_smoke_service_account_email
  }
}
