# TIER 2 - ECS Fargate. No servers to patch, which removes an entire category
# of work that Day 1 and Day 3 exist to teach. Point that out: you learn how
# to manage a box so that you understand what Fargate is doing for you.

resource "aws_ecs_cluster" "main" {
  name = local.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "service" {
  for_each          = var.services
  name              = "/ecs/${local.name}/${each.key}"
  retention_in_days = 7
}

# Execution role: what ECS itself needs (pull images, write logs, read secrets)
resource "aws_iam_role" "execution" {
  name = "${local.name}-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "execution_secrets" {
  name = "read-db-secret"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [aws_secretsmanager_secret.db.arn]
    }]
  })
}

# Task role: what the application code itself is allowed to do. Separate from
# the execution role on purpose - the app should not inherit the permissions
# ECS needs to start it.
resource "aws_iam_role" "task" {
  name = "${local.name}-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_ecs_task_definition" "service" {
  for_each = var.services

  family                   = "${local.name}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64" # cheaper per vCPU than X86_64
  }

  container_definitions = jsonencode([{
    name      = each.key
    image     = "${aws_ecr_repository.service[each.key].repository_url}:latest"
    essential = true

    portMappings = [{
      containerPort = each.value.port
      protocol      = "tcp"
    }]

    environment = [
      { name = "NODE_ENV", value = "production" },
      { name = "PORT", value = tostring(each.value.port) },
      { name = "ORDERS_URL", value = "http://orders.${local.name}.local:3001" },
      { name = "KITCHEN_URL", value = "http://kitchen.${local.name}.local:3002" },
      { name = "DISPATCH_URL", value = "http://dispatch.${local.name}.local:3003" },
      { name = "OTEL_SERVICE_NAMESPACE", value = "daig" }
    ]

    # Injected by ECS from Secrets Manager at task start. The value never
    # appears in the task definition, in Terraform state, or in the console.
    secrets = [{
      name      = "DATABASE_URL"
      valueFrom = "${aws_secretsmanager_secret.db.arn}:url::"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.service[each.key].name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ecs"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "node -e \"require('http').get('http://127.0.0.1:${each.value.port}/healthz',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))\""]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 30
    }
  }])
}

resource "aws_service_discovery_private_dns_namespace" "main" {
  name = "${local.name}.local"
  vpc  = aws_vpc.main.id
}

resource "aws_service_discovery_service" "service" {
  for_each = var.services
  name     = each.key

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_service" "service" {
  for_each = var.services

  name            = each.key
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.service[each.key].arn
  desired_count   = each.value.replicas
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.service[each.key].arn
  }

  # Only "orders" is exposed through the load balancer. Kitchen and dispatch
  # are internal, which is what makes them the application tier rather than
  # the presentation tier.
  dynamic "load_balancer" {
    for_each = each.key == "orders" ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.orders.arn
      container_name   = each.key
      container_port   = each.value.port
    }
  }

  # Circuit breaker with rollback. This is the CrowdStrike lesson expressed as
  # infrastructure: a deployment that cannot become healthy is automatically
  # reverted rather than left half-applied.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  health_check_grace_period_seconds = each.key == "orders" ? 60 : null

  # Application Auto Scaling owns desired_count at runtime. Without this, the
  # next `terraform apply` resets it to each.value.replicas and terminates live
  # capacity mid-spike — the exact iftar scenario this stack teaches.
  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [aws_lb_listener.https]
}
