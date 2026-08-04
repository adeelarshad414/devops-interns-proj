output "application_url" {
  description = "Public entry point"
  value       = "http://${aws_lb.main.dns_name}"
}

output "database_endpoint" {
  description = "RDS endpoint. Private - reachable only from the application tier."
  value       = aws_db_instance.main.address
}

output "database_secret_arn" {
  description = "Where the connection string actually lives"
  value       = aws_secretsmanager_secret.db.arn
}

output "ecr_repositories" {
  description = "Push targets for CI"
  value       = { for k, v in aws_ecr_repository.service : k => v.repository_url }
}

output "ecs_cluster" {
  value = aws_ecs_cluster.main.name
}

output "estimated_monthly_cost_note" {
  description = "Read this before you leave for the day"
  value = join(" ", [
    "RDS ${var.db_instance_class} plus one NAT gateway plus the ALB are the",
    "standing charges and they accrue whether or not anyone is using Daig.",
    "All monthly figures derive from 730 hours. Run terraform destroy when",
    "you finish for the day."
  ])
}
