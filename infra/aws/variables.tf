variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "domain_name" {
  description = "Domain for the ALB TLS certificate. The default is a placeholder so `terraform validate` passes; supply a real domain (with a Route 53 zone) to apply."
  type        = string
  default     = "daig.example.com"
}

variable "environment" {
  description = "Environment name, used in resource names"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "How many availability zones to span. Two is the minimum for an ALB."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2
    error_message = "An ALB requires subnets in at least two availability zones."
  }
}

variable "db_instance_class" {
  description = "RDS instance class. The most expensive line in this stack."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_name" {
  type    = string
  default = "daig"
}

variable "db_username" {
  type    = string
  default = "daig"
}

variable "services" {
  description = "The three application-tier services and their ports"
  type = map(object({
    port     = number
    cpu      = number
    memory   = number
    replicas = number
  }))
  default = {
    orders   = { port = 3001, cpu = 256, memory = 512, replicas = 2 }
    kitchen  = { port = 3002, cpu = 256, memory = 512, replicas = 1 }
    dispatch = { port = 3003, cpu = 256, memory = 512, replicas = 1 }
  }
}
