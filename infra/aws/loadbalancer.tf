# TIER 1 entry point.

resource "aws_lb" "main" {
  name               = local.name
  load_balancer_type = "application"
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.alb.id]

  enable_deletion_protection = var.environment == "prod"
  idle_timeout               = 60

  tags = { Name = local.name, Tier = "presentation" }
}

resource "aws_lb_target_group" "orders" {
  name        = "${local.name}-orders"
  port        = 3001
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/healthz"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  # Give in-flight requests time to finish before the target is removed.
  # Without this, every deploy drops a handful of live orders.
  deregistration_delay = 30

  tags = { Name = "${local.name}-orders" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.orders.arn
  }
}

# TODO before any real use: terminate TLS here with an ACM certificate and
# redirect port 80 to 443. Plain HTTP is acceptable in a training VPC and
# nowhere else. tfsec will flag this, and it is right to.
