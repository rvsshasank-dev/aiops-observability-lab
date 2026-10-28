output "network_name" {
  description = "VPC name."
  value       = google_compute_network.this.name
}

output "network_id" {
  description = "VPC ID."
  value       = google_compute_network.this.id
}

output "subnet_name" {
  description = "Subnet name."
  value       = google_compute_subnetwork.this.name
}

output "subnet_id" {
  description = "Subnet ID."
  value       = google_compute_subnetwork.this.id
}

output "pods_range_name" {
  description = "Secondary range name for pods."
  value       = "${var.name_prefix}-pods"
}

output "services_range_name" {
  description = "Secondary range name for services."
  value       = "${var.name_prefix}-services"
}

output "router_name" {
  description = "Cloud Router name."
  value       = google_compute_router.this.name
}

output "nat_name" {
  description = "Cloud NAT name."
  value       = google_compute_router_nat.this.name
}
