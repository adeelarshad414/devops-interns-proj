# TIER 2 - Cloud Run. Scales to the min_instances floor and up on request
# concurrency, which suits the iftar spike well; the tradeoff is cold starts
# at the floor, which is why min_instances is not zero.

resource "google_service_account" "run" {
  account_id   = "${local.name}-run"
  display_name = "Daig Cloud Run runtime"
}

resource "google_secret_manager_secret_iam_member" "run_db" {
  secret_id = google_secret_manager_secret.db_url.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.run.email}"
}

resource "google_cloud_run_v2_service" "service" {
  for_each = var.services

  name     = "${local.name}-${each.key}"
  location = var.region

  # Only orders is publicly reachable; see the IAM binding below.
  ingress = each.key == "orders" ? "INGRESS_TRAFFIC_ALL" : "INGRESS_TRAFFIC_INTERNAL_ONLY"

  template {
    service_account = google_service_account.run.email

    scaling {
      min_instance_count = each.value.min_instances
      max_instance_count = each.value.max_instances
    }

    vpc_access {
      connector = google_vpc_access_connector.main.id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/daig/${each.key}:latest"

      ports {
        container_port = each.value.port
      }

      resources {
        limits = {
          cpu    = each.value.cpu
          memory = each.value.memory
        }
        cpu_idle = false
      }

      env {
        name  = "NODE_ENV"
        value = "production"
      }

      env {
        name  = "PORT"
        value = tostring(each.value.port)
      }

      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_url.secret_id
            version = "latest"
          }
        }
      }

      startup_probe {
        http_get {
          path = "/healthz"
          port = each.value.port
        }
        initial_delay_seconds = 5
        period_seconds        = 3
        failure_threshold     = 10
      }

      liveness_probe {
        http_get {
          path = "/healthz"
          port = each.value.port
        }
        period_seconds = 30
      }
    }

    max_instance_request_concurrency = 80
    timeout                          = "30s"
  }

  # Traffic block is where progressive delivery happens on Cloud Run: point a
  # percentage at a named revision, watch, then promote.
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  depends_on = [google_secret_manager_secret_version.db_url]
}

resource "google_cloud_run_v2_service_iam_member" "public_orders" {
  location = google_cloud_run_v2_service.service["orders"].location
  name     = google_cloud_run_v2_service.service["orders"].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Internal services are callable only by the runtime service account.
resource "google_cloud_run_v2_service_iam_member" "internal" {
  for_each = { for k, v in var.services : k => v if k != "orders" }

  location = google_cloud_run_v2_service.service[each.key].location
  name     = google_cloud_run_v2_service.service[each.key].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.run.email}"
}
