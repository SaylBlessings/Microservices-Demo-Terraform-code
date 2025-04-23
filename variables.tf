variable "project_id" {
  description = "The GCP project ID to deploy resources into"
  type        = string
}

variable "region" {
  description = "The GCP region to deploy resources into"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone to deploy the GKE cluster into"
  type        = string
  default     = "us-central1-a"
}

variable "admin_cidr" {
  description = "CIDR block for admin access to the GKE master"
  type        = string
}

variable "github_owner" {
  description = "GoogleCloudPlatform"
  type        = string
}

variable "github_repo" {
  description = "GoogleCloudPlatform"
  type        = string
}

variable "iap_user_email" {
  description = "welcome..."
  type        = string
}