variable "project_id" {
  description = "GCP project that owns the lab."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project ID."
  }
}

variable "billing_account" {
  description = "Billing account ID used for the monthly budget (XXXXXX-XXXXXX-XXXXXX)."
  type        = string

  validation {
    condition     = can(regex("^[0-9A-F]{6}-[0-9A-F]{6}-[0-9A-F]{6}$", var.billing_account))
    error_message = "billing_account must look like XXXXXX-XXXXXX-XXXXXX."
  }
}

variable "budget_amount_usd" {
  description = "Monthly budget in whole US dollars. This is an alert threshold, not a hard cap."
  type        = number
  default     = 25

  validation {
    condition     = var.budget_amount_usd > 0 && var.budget_amount_usd == floor(var.budget_amount_usd)
    error_message = "budget_amount_usd must be a positive whole number."
  }
}

variable "state_bucket_location" {
  description = "Location for the Terraform state bucket."
  type        = string
  default     = "us-central1"
}

variable "labels" {
  description = "Labels applied to bootstrap resources."
  type        = map(string)
  default = {
    environment = "lab"
    managed-by  = "terraform"
    owner       = "aiops-observability-lab"
  }
}
