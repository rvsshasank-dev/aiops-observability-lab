variable "project_id" {
  description = "GCP project."
  type        = string
}

variable "region" {
  description = "Region for the VPC subnet and Cloud NAT."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "subnet_cidr" {
  description = "Primary node subnet range."
  type        = string
}

variable "pods_cidr" {
  description = "Secondary range for pods."
  type        = string
}

variable "services_cidr" {
  description = "Secondary range for services."
  type        = string
}

variable "labels" {
  description = "Labels applied to network resources."
  type        = map(string)
}
