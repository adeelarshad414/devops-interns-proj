# The iftar spike, in code.
#
# Note the asymmetry: scale out fast, scale in slowly. Capacity that flaps is
# worse than slightly too much capacity, and the spike arrives faster than
# tasks can start. This is the same reasoning as the Kubernetes HPA behaviour
# block in k8s/base/hpa.yaml - deliberately, so interns see the pattern twice.

resource "aws_appautoscaling_target" "orders" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.service["orders"].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = 2
  max_capacity       = 20
}

resource "aws_appautoscaling_policy" "orders_cpu" {
  name               = "${local.name}-orders-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.orders.service_namespace
  resource_id        = aws_appautoscaling_target.orders.resource_id
  scalable_dimension = aws_appautoscaling_target.orders.scalable_dimension

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 60
    scale_in_cooldown  = 300
    scale_out_cooldown = 30
  }
}

# Scheduled pre-scaling. The best autoscaler in the world cannot react to a
# spike that arrives in twenty seconds - so for a predictable event, do not
# react. Anticipate. Ask the room why this is better than a bigger minimum.
resource "aws_appautoscaling_scheduled_action" "pre_iftar" {
  name               = "${local.name}-pre-iftar"
  service_namespace  = aws_appautoscaling_target.orders.service_namespace
  resource_id        = aws_appautoscaling_target.orders.resource_id
  scalable_dimension = aws_appautoscaling_target.orders.scalable_dimension

  # 18:00 Pakistan time = 13:00 UTC. Revisit seasonally: iftar moves, cron
  # does not. A hard-coded prayer time is a bug with a calendar fuse on it.
  schedule = "cron(0 13 * * ? *)"

  scalable_target_action {
    min_capacity = 10
    max_capacity = 20
  }
}

resource "aws_appautoscaling_scheduled_action" "post_iftar" {
  name               = "${local.name}-post-iftar"
  service_namespace  = aws_appautoscaling_target.orders.service_namespace
  resource_id        = aws_appautoscaling_target.orders.resource_id
  scalable_dimension = aws_appautoscaling_target.orders.scalable_dimension

  schedule = "cron(30 15 * * ? *)"

  scalable_target_action {
    min_capacity = 2
    max_capacity = 20
  }
}

# ---------------------------------------------------------------- parity + RPS
# The spike propagates orders -> kitchen -> dispatch. If only orders scales, a
# fixed kitchen/dispatch becomes the bottleneck the moment orders fans out.
resource "aws_appautoscaling_target" "downstream" {
  for_each           = toset(["kitchen", "dispatch"])
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.service[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = 1
  max_capacity       = 12
}

resource "aws_appautoscaling_policy" "downstream_cpu" {
  for_each           = aws_appautoscaling_target.downstream
  name               = "${local.name}-${each.key}-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = each.value.service_namespace
  resource_id        = each.value.resource_id
  scalable_dimension = each.value.scalable_dimension

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 60
    scale_in_cooldown  = 300
    scale_out_cooldown = 30
  }
}

# Request-count scaling for orders — usually a better signal than CPU for spiky
# HTTP. Hold ~200 in-flight requests per ALB target; scale to keep that steady.
resource "aws_appautoscaling_policy" "orders_requests" {
  name               = "${local.name}-orders-requests"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.orders.service_namespace
  resource_id        = aws_appautoscaling_target.orders.resource_id
  scalable_dimension = aws_appautoscaling_target.orders.scalable_dimension

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.main.arn_suffix}/${aws_lb_target_group.orders.arn_suffix}"
    }
    target_value       = 200
    scale_in_cooldown  = 300
    scale_out_cooldown = 30
  }
}
