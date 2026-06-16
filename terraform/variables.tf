variable "gcp_project_id" {
  description = "GCP project to deploy into"
  type        = string
}

variable "gcp_region" {
  type    = string
  default = "europe-west1"
}

variable "project_name" {
  type    = string
  default = "multicloud-pipeline"
}
