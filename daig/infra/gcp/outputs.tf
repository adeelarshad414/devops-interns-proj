output "application_url" {
  value = google_cloud_run_v2_service.service["orders"].uri
}

output "database_private_ip" {
  value = google_sql_database_instance.main.private_ip_address
}

output "database_secret" {
  value = google_secret_manager_secret.db_url.secret_id
}

output "registry" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/daig"
}

output "cost_note" {
  value = join(" ", [
    "Cloud SQL and the VPC Access Connector both bill continuously, whether or",
    "not Cloud Run has any traffic. Those two are your standing cost. Monthly",
    "figures derive from 730 hours. terraform destroy at the end of the day."
  ])
}
