variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_number" {
  description = "GCP Project Number"
  type        = string
}

variable "project_name" {
  description = "Name of the project used for naming of cloud run instance, database and user"
  type        = string
  default     = "sunrise"
}

variable "github_repository" {
  description = "GitHub repo in format owner/repo"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west4"
}

variable "db_password" {
  description = "Password for the MySQL database"
  type        = string
  sensitive   = true
}