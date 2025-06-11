provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_project_service" "run" {
  service = "run.googleapis.com"
}

resource "google_project_service" "sqladmin" {
  service = "sqladmin.googleapis.com"
}

resource "google_project_service" "cloudresourcemanager" {
  service = "cloudresourcemanager.googleapis.com"
  project = var.project_id
}

resource "google_project_service" "artifactregistry" {
  service = "artifactregistry.googleapis.com"
}

resource "google_service_account" "cloud_run_sa" {
  account_id   = "${var.project_name}-cloud-run-sa"
  display_name = "Cloud Run Service Account for ${var.project_name}"
}

resource "google_project_iam_member" "cloud_run_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_artifact_registry_repository" "default_backend" {
  location      = var.region
  repository_id = "${var.project_name}-backend"
  description   = "Docker repo for ${var.project_name} backend"
  format        = "DOCKER"

  depends_on = [google_project_service.artifactregistry]
}

resource "google_sql_database_instance" "default" {
  name                 = "${var.project_name}-db"
  database_version     = "MYSQL_8_0"
  region               = var.region
  deletion_protection  = false

  settings {
    tier              = "db-f1-micro"
    availability_type = "ZONAL"

    backup_configuration {
      enabled = false
    }
  }

  depends_on = [google_project_service.sqladmin]
}

resource "google_sql_database" "db" {
  name     = var.project_name
  instance = google_sql_database_instance.default.name
}

resource "google_sql_user" "default" {
  name     = var.project_name
  instance = google_sql_database_instance.default.name
  password = var.db_password
}

resource "google_cloud_run_service" "default" {
  name     = "${var.project_name}-backend"
  location = var.region

  template {
    metadata {
      annotations = {
        "run.googleapis.com/cloudsql-instances" = google_sql_database_instance.default.connection_name
      }
    }

    spec {
      service_account_name = google_service_account.cloud_run_sa.email

      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.project_name}-backend/${var.project_name}-backend:latest"

        env {
          name  = "DB_USER"
          value = google_sql_user.default.name
        }

        env {
          name  = "DB_PASSWORD"
          value = var.db_password
        }

        env {
          name  = "DB_NAME"
          value = google_sql_database.db.name
        }

        env {
          name  = "DB_HOST"
          value = "/cloudsql/${google_sql_database_instance.default.connection_name}"
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    google_project_service.run,
    google_project_iam_member.cloud_run_sql_client,
    google_artifact_registry_repository.default_backend
  ]
}

resource "google_storage_bucket" "terraform_state" {
  name     = "${var.project_id}-terraform-state"
  location = var.region

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}
