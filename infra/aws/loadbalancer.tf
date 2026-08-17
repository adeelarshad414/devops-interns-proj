# TIER 1 entry point — the public Application Load Balancer.
# TLS termination, WAF, and access logs are wired in edge.tf.

resource "aws_lb" "main" {
  name               = local.name
  load_balancer_type = "application"
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.alb.id]

  enable_deletion_protection = var.environment == "prod"
  idle_timeout               = 60

  # Sanitise malformed headers before they reach the app (tfsec/CIS default).
  drop_invalid_header_fields = true

  # Who talked to the edge, and when. The bucket + delivery policy is in edge.tf.
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "alb"
    enabled = true
  }

  depends_on = [aws_s3_bucket_policy.alb_logs]

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

# Port 80 no longer serves traffic — it redirects to HTTPS. A plain-HTTP entry
# point on a payment-carrying app is a downgrade waiting to happen.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# TLS terminates here. TLS 1.2+ only via the ELB security policy; the certificate
# is the ACM cert in edge.tf.
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.orders.arn
  }
}
