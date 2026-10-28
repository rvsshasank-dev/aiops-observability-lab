variable "project_id" {
  description = "GCP project that owns the lab."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project ID."
  }
}

variable "region" {
  description = "Region for the VPC, subnet, Cloud NAT and regional buckets."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone for the zonal GKE cluster and node pool."
  type        = string
  default     = "us-central1-a"
}

variable "name_prefix" {
  description = "Prefix for project-owned resource names."
  type        = string
  default     = "aiops-lab"
}

variable "cluster_name" {
  description = "GKE cluster name."
  type        = string
  default     = "aiops-lab"
}

variable "network_cidr" {
  description = "Primary subnet range for nodes."
  type        = string
  default     = "10.10.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary range for pods."
  type        = string
  default     = "10.16.0.0/14"
}

variable "services_cidr" {
  description = "Secondary range for services."
  type        = string
  default     = "10.20.0.0/20"
}

variable "master_ipv4_cidr_block" {
  description = " /28 range for the GKE control plane."
  type        = string
  default     = "172.16.0.0/28"
}

variable "node_machine_type" {
  description = "Machine type for the general node pool."
  type        = string
  default     = "e2-standard-2"
}

variable "node_min_count" {
  description = "Minimum nodes in the general pool."
  type        = number
  default     = 1

  validation {
    condition     = var.node_min_count >= 0
    error_message = "node_min_count must be zero or greater."
  }
}

variable "node_max_count" {
  description = "Maximum nodes in the general pool."
  type        = number
  default     = 3

  validation {
    condition     = var.node_max_count >= 1
    error_message = "node_max_count must be at least 1."
  }
}

variable "node_disk_size_gb" {
  description = "Boot disk size for each node."
  type        = number
  default     = 50
}

variable "release_channel" {
  description = "GKE release channel."
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "release_channel must be RAPID, REGULAR or STABLE."
  }
}

variable "master_authorized_networks" {
  description = "Optional CIDRs allowed to reach the public control-plane endpoint. Empty means no CIDR restriction."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "telemetry_retention_days" {
  description = "Bucket-level backstop for Tempo and Loki object retention."
  type        = number
  default     = 14

  validation {
    condition     = var.telemetry_retention_days >= 1
    error_message = "telemetry_retention_days must be at least 1."
  }
}

variable "labels" {
  description = "Labels applied to project-owned resources."
  type        = map(string)
  default = {
    environment = "lab"
    managed-by  = "terraform"
    owner       = "aiops-observability-lab"
  }
}
