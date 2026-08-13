variable "project_id" {
  description = "GCP project id. No default - an accidental deploy into the wrong project is expensive."
  type        = string
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "environment" {
  type    = string
  default = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "db_tier" {
  description = "Cloud SQL machine type. The most expensive line in this stack."
  type        = string
  default     = "db-f1-micro"
}

variable "services" {
  type = map(object({
    port          = number
    cpu           = string
    memory        = string
    min_instances = number
    max_instances = number
  }))
  # COST NOTE - this default was changed after scripts/cost-model.py exposed it.
  #
  # Originally all three services had min_instances = 1. Combined with
  # cpu_idle = false (CPU always allocated) that made Cloud Run behave like
  # always-on compute and cost ~$0.27/hr - more than the equivalent Fargate
  # stack - which discards the single thing Cloud Run is good at.
  #
  # Now: orders keeps a warm instance because it is the public entry point and
  # a cold start on the first request of a demo is a bad look. kitchen and
  # dispatch scale to zero, because a cold start on an internal call inside an
  # already-slow request path is invisible to the interns.
  #
  # Run `python3 scripts/cost-model.py` after changing any of these.
  default = {
    orders   = { port = 3001, cpu = "1", memory = "512Mi", min_instances = 1, max_instances = 20 }
    kitchen  = { port = 3002, cpu = "1", memory = "512Mi", min_instances = 0, max_instances = 10 }
    dispatch = { port = 3003, cpu = "1", memory = "512Mi", min_instances = 0, max_instances = 10 }
  }
}
