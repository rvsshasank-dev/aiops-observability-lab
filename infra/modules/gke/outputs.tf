output "cluster_name" {
  description = "GKE cluster name."
  value       = google_container_cluster.this.name
}

output "cluster_id" {
  description = "GKE cluster ID."
  value       = google_container_cluster.this.id
}

output "location" {
  description = "Cluster location (zone)."
  value       = google_container_cluster.this.location
}

output "endpoint" {
  description = "Public control-plane endpoint."
  value       = google_container_cluster.this.endpoint
  sensitive   = true
}

output "ca_certificate" {
  description = "Cluster CA certificate."
  value       = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "node_pool_name" {
  description = "Managed general node pool name."
  value       = google_container_node_pool.general.name
}
