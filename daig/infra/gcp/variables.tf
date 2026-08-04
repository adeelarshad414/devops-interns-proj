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
  default = {
    orders   = { port = 3001, cpu = "1", memory = "512Mi", min_instances = 1, max_instances = 20 }
    kitchen  = { port = 3002, cpu = "1", memory = "512Mi", min_instances = 1, max_instances = 10 }
    dispatch = { port = 3003, cpu = "1", memory = "512Mi", min_instances = 1, max_instances = 10 }
  }
}
