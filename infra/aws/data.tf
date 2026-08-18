# TIER 3 - managed PostgreSQL.
# The password is generated and stored in Secrets Manager. It is never in
# Terraform variables, never in a tfvars file, never in the repo.

resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "${local.name}/database"
  description             = "Daig database credentials"
  recovery_window_in_days = 0 # teaching environment; use 7+ in production
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    dbname   = var.db_name
    host     = aws_db_instance.main.address
    port     = 5432
    # sslmode=require forces TLS to RDS (match the Azure connection string).
    # Enforce it server-side too via rds.force_ssl=1 in the parameter group.
    url      = "postgresql://${var.db_username}:${urlencode(random_password.db.result)}@${aws_db_instance.main.address}:5432/${var.db_name}?sslmode=require"
  })
}

resource "aws_db_subnet_group" "main" {
  name       = local.name
  subnet_ids = aws_subnet.private[*].id
  tags       = { Name = local.name }
}

# Enforce TLS at the server. sslmode=require on the client is only half the job;
# rds.force_ssl=1 makes RDS reject any cleartext connection outright.
resource "aws_db_parameter_group" "main" {
  name   = local.name
  family = "postgres16"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = { Name = local.name }
}

resource "aws_db_instance" "main" {
  identifier     = local.name
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  # TRADE-OFF, worth understanding. This password lands in Terraform state in
  # cleartext. The stronger option is `manage_master_user_password = true`, which
  # hands password generation+rotation to RDS and keeps it out of state entirely.
  # We don't use it here because this module COMPOSES the full DATABASE_URL string
  # (see the secret above) for the app to read - and with RDS-managed passwords
  # Terraform never sees the plaintext, so it cannot build that URL. Adopting it
  # is a real improvement but requires reworking the app to read structured creds
  # (username/password/host) from the RDS-managed secret instead of a ready-made
  # URL. Left as a deliberate, documented exercise rather than a half-done change.
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  backup_retention_period = var.environment == "prod" ? 14 : 1
  skip_final_snapshot     = var.environment != "prod"
  deletion_protection     = var.environment == "prod"

  # Multi-AZ doubles the cost and halves the failover time. In prod that is
  # obviously worth it; in a training account it obviously is not. Making the
  # tradeoff explicit in code is better than hiding it in a default.
  multi_az = var.environment == "prod"

  performance_insights_enabled    = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  auto_minor_version_upgrade = true
  apply_immediately          = var.environment != "prod"

  tags = { Name = local.name, Tier = "data" }
}
