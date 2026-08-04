# TIER 3 - Cloud SQL for PostgreSQL, private IP only.

resource "random_password" "db" {
  length  = 32
  special = true
}

resource "google_sql_database_instance" "main" {
  name             = "${local.name}-pg"
  database_version = "POSTGRES_16"
  region           = var.region

  deletion_protection = var.environment == "prod"

  settings {
    tier              = var.db_tier
    availability_type = var.environment == "prod" ? "REGIONAL" : "ZONAL"
    disk_size         = 20
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    ip_configuration {
      # No public IP. Reachable only through the VPC connector.
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.main.id
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled                        = true
      start_time                     = "02:00"
      point_in_time_recovery_enabled = var.environment == "prod"
      transaction_log_retention_days = var.environment == "prod" ? 7 : 1
    }

    database_flags {
      name  = "log_min_duration_statement"
      value = "500" # log anything slower than 500ms; Day 4 uses this
    }

    insights_config {
      query_insights_enabled  = true
      record_application_tags = true
    }
  }

  depends_on = [google_service_networking_connection.main]
}

resource "google_sql_database" "daig" {
  name     = "daig"
  instance = google_sql_database_instance.main.name
}

resource "google_sql_user" "daig" {
  name     = "daig"
  instance = google_sql_database_instance.main.name
  password = random_password.db.result
}

resource "google_secret_manager_secret" "db_url" {
  secret_id = "${local.name}-database-url"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required]
}

resource "google_secret_manager_secret_version" "db_url" {
  secret      = google_secret_manager_secret.db_url.id
  secret_data = "postgresql://daig:${urlencode(random_password.db.result)}@${google_sql_database_instance.main.private_ip_address}:5432/daig"
}
