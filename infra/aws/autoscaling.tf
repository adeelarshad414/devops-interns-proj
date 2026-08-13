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
