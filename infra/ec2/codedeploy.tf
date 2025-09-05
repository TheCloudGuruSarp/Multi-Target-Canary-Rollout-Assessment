// --- IAM Role for CodeDeploy ---
// This role allows CodeDeploy to interact with EC2, ASGs, and ELBs.
resource "aws_iam_role" "codedeploy_role" {
  name = "podinfo-codedeploy-service-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "codedeploy.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_policy" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

// --- CodeDeploy Application ---
// A CodeDeploy application is a container for deployment groups.
resource "aws_codedeploy_app" "ec2_app" {
  name             = "podinfo-ec2"
  compute_platform = "Server"
}

// --- CodeDeploy Deployment Group ---
// This defines the blue/green deployment strategy for our EC2 stack.
resource "aws_codedeploy_deployment_group" "ec2_dg" {
  app_name              = aws_codedeploy_app.ec2_app.name
  deployment_group_name = "podinfo-ec2-blue-green-dg"
  service_role_arn      = aws_iam_role.codedeploy_role.arn
  autoscaling_groups    = [aws_autoscaling_group.main.name]

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  # Link the alarm to this deployment group
  alarm_configuration {
    alarms  = [aws_cloudwatch_metric_alarm.ec2_unhealthy_hosts.alarm_name]
    enabled = true
  }

  // How CodeDeploy should handle traffic shifting and instance termination.
  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  // Connect CodeDeploy to our ALB and target groups.
  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.http.arn]
      }
      target_group {
        name = aws_lb_target_group.blue.name
      }
      target_group {
        name = aws_lb_target_group.green.name
      }
    }
  }

  // Automatically roll back if a deployment fails.
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }
}

# This alarm will trigger if the new 'green' target group has unhealthy hosts
# for too long during a deployment.
resource "aws_cloudwatch_metric_alarm" "ec2_unhealthy_hosts" {
  alarm_name          = "Podinfo-EC2-Unhealthy-Hosts-During-Deployment"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "1" # Should have at least 1 healthy host in the green group
  alarm_description   = "Triggers a rollback if the green target group does not stabilize."
  dimensions = {
    TargetGroup    = aws_lb_target_group.green.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }
}
