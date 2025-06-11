output "cloud_run_url" {
  value = google_cloud_run_service.default.status[0].url
}

output "cloud_sql_connection_name" {
  value = google_sql_database_instance.default.connection_name
}