locals {
  name = "daig-${var.environment}"
}

resource "google_project_service" "required" {
  for_each = toset([
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "vpcaccess.googleapis.com",
    "compute.googleapis.com",
  ])

  service            = each.key
  disable_on_destroy = false
}

# ---------------- network ----------------
resource "google_compute_network" "main" {
  name                    = local.name
  auto_create_subnetworks = false
  depends_on              = [google_project_service.required]
}

resource "google_compute_subnetwork" "main" {
  name          = "${local.name}-subnet"
  network       = google_compute_network.main.id
  region        = var.region
  ip_cidr_range = "10.30.0.0/20"

  private_ip_google_access = true
}

# Cloud Run is serverless and lives outside your VPC. A connector is what lets
# it reach private resources like Cloud SQL. This is the piece people miss.
resource "google_vpc_access_connector" "main" {
  name          = "${local.name}-conn"
  region        = var.region
  network       = google_compute_network.main.name
  ip_cidr_range = "10.31.0.0/28"
  min_instances = 2
  max_instances = 3

  depends_on = [google_project_service.required]
}

resource "google_compute_global_address" "private_ip" {
  name          = "${local.name}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.id
}

resource "google_service_networking_connection" "main" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip.name]
}

# ---------------- registry ----------------
resource "google_artifact_registry_repository" "main" {
  location      = var.region
  repository_id = "daig"
  format        = "DOCKER"
  description   = "Daig service images"

  docker_config {
    immutable_tags = true
  }

  depends_on = [google_project_service.required]
}
