variable "project_id" {
  description = "GCP project."
  type        = string
}

variable "region" {
  description = "Region for the buckets."
  type        = string
}

variable "telemetry_retention_days" {
  description = "Bucket-level retention backstop for Tempo and Loki."
  type        = number
}

variable "force_destroy" {
  description = "Allow Terraform to delete non-empty telemetry buckets."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels applied to buckets."
  type        = map(string)
}
