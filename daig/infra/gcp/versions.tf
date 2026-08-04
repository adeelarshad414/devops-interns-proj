terraform {
  required_version = ">= 1.9.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.40"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # backend "gcs" {
  #   bucket = "tkxel-daig-tfstate"
  #   prefix = "gcp/daig"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region

  default_labels = {
    project     = "daig"
    environment = var.environment
    managed_by  = "terraform"
    cost_centre = "training"
  }
}
