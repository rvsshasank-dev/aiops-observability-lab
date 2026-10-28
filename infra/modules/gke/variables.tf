variable "project_id" {
  description = "GCP project."
  type        = string
}

variable "zone" {
  description = "Zone for the zonal cluster."
  type        = string
}

variable "cluster_name" {
  description = "GKE cluster name."
  type        = string
}

variable "network_name" {
  description = "VPC name."
  type        = string
}

variable "subnet_name" {
  description = "Subnet name."
  type        = string
}

variable "pods_range_name" {
  description = "Secondary range name for pods."
  type        = string
}

variable "services_range_name" {
  description = "Secondary range name for services."
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "/28 range for the control plane."
  type        = string
}

variable "node_service_account_email" {
  description = "Node pool service account email."
  type        = string
}

variable "node_machine_type" {
  description = "Machine type for the general node pool."
  type        = string
}

variable "node_min_count" {
  description = "Minimum nodes."
  type        = number
}

variable "node_max_count" {
  description = "Maximum nodes."
  type        = number
}

variable "node_disk_size_gb" {
  description = "Node boot disk size."
  type        = number
}

variable "release_channel" {
  description = "GKE release channel."
  type        = string
}

variable "master_authorized_networks" {
  description = "Optional CIDRs allowed to reach the public control-plane endpoint."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
}

variable "labels" {
  description = "Labels applied to the cluster and nodes."
  type        = map(string)
}
