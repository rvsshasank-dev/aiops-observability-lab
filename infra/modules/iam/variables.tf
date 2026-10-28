variable "project_id" {
  description = "GCP project."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for service account IDs."
  type        = string
}

variable "tempo_bucket" {
  description = "Bucket that Tempo may write to."
  type        = string
}

variable "loki_bucket" {
  description = "Bucket that Loki may write to."
  type        = string
}

variable "wif_smoke_bucket" {
  description = "Bucket used only by the Workload Identity smoke test."
  type        = string
}

variable "labels" {
  description = "Labels applied to service accounts."
  type        = map(string)
}
