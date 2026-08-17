# Three security groups, one per tier, each allowing traffic only from the tier
# above it. Read them top to bottom and the three-tier model is right there in
# the rules - which is the clearest possible way to teach it.

resource "aws_security_group" "alb" {
  name        = "${local.name}-alb"
  description = "Public entry point"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from the internet (redirected to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from the internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "To the application tier"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = { Name = "${local.name}-alb", Tier = "presentation" }
}

resource "aws_security_group" "app" {
  name        = "${local.name}-app"
  description = "Application tier - reachable only from the ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "From the load balancer only"
    from_port       = 3000
    to_port         = 3010
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "Service to service inside the tier"
    from_port   = 3000
    to_port     = 3010
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Outbound for image pulls, OTLP and the database"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-app", Tier = "application" }
}

resource "aws_security_group" "db" {
  name        = "${local.name}-db"
  description = "Data tier - reachable only from the application tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from the application tier only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  # No egress rule at all. A database has no business making outbound
  # connections, and if it starts trying to, you want it to fail.

  tags = { Name = "${local.name}-db", Tier = "data" }
}
