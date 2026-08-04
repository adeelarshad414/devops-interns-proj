variable "location" {
  type    = string
  default = "northeurope"
}

variable "environment" {
  type    = string
  default = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "db_sku" {
  description = "PostgreSQL Flexible Server SKU. The most expensive line in this stack."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "services" {
  type = map(object({
    port         = number
    cpu          = number
    memory       = string
    min_replicas = number
    max_replicas = number
    external     = bool
  }))
  default = {
    orders   = { port = 3001, cpu = 0.5, memory = "1Gi", min_replicas = 2, max_replicas = 20, external = true }
    kitchen  = { port = 3002, cpu = 0.5, memory = "1Gi", min_replicas = 1, max_replicas = 10, external = false }
    dispatch = { port = 3003, cpu = 0.5, memory = "1Gi", min_replicas = 1, max_replicas = 10, external = false }
  }
}
