# A managed API gateway (HTTP API) in front of the ALB — the edge-policy layer a
# raw load balancer doesn't give you: per-route throttling, structured access
# logs, and a stable public entry decoupled from the LB. The gateway reaches the
# ALB privately over a VPC Link.
#
# NOTE: in a real design the ALB would usually be INTERNAL, with API Gateway as
# the sole public entry. Here it validates against the existing internet-facing
# ALB so the pattern is teachable without restructuring the network.

resource "aws_security_group" "apigw" {
  name        = "${local.name}-apigw"
  description = "API Gateway VPC link"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "To the ALB / application tier"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = { Name = "${local.name}-apigw" }
}

resource "aws_apigatewayv2_vpc_link" "main" {
  name               = local.name
  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.apigw.id]
  tags               = { Name = local.name }
}

resource "aws_apigatewayv2_api" "main" {
  name          = local.name
  protocol_type = "HTTP"
  tags          = { Name = local.name }
}

resource "aws_apigatewayv2_integration" "alb" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = aws_lb_listener.https.arn
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
}

resource "aws_apigatewayv2_route" "proxy" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}

resource "aws_cloudwatch_log_group" "apigw" {
  name              = "/apigw/${local.name}"
  retention_in_days = 14
  tags              = { Name = "${local.name}-apigw" }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  # Throttling is the gateway feature a load balancer can't give you: cap the
  # blast radius of a client (or a bad deploy) before it reaches the app.
  default_route_settings {
    throttling_burst_limit = 200
    throttling_rate_limit  = 100
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw.arn
    format = jsonencode({
      requestId = "$context.requestId"
      ip        = "$context.identity.sourceIp"
      route     = "$context.routeKey"
      status    = "$context.status"
      latency   = "$context.responseLatency"
    })
  }

  tags = { Name = local.name }
}
