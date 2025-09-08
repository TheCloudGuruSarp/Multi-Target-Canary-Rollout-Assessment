resource "aws_iam_role" "codedeploy_lambda_role" {
  name = "podinfo-codedeploy-lambda-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "codedeploy.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_lambda_policy" {
  role       = aws_iam_role.codedeploy_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRoleForLambda"
}

resource "aws_codedeploy_app" "lambda_app" {
  name             = "podinfo-lambda"
  compute_platform = "Lambda"
}

resource "aws_codedeploy_deployment_group" "lambda_dg" {
  app_name              = aws_codedeploy_app.lambda_app.name
  deployment_group_name = "podinfo-lambda-canary-dg"
  service_role_arn      = aws_iam_role.codedeploy_lambda_role.arn

  deployment_config_name = "CodeDeployDefault.LambdaCanary10Percent5Minutes"

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  alarm_configuration {
    alarms  = [aws_cloudwatch_metric_alarm.lambda_errors.alarm_name]
    enabled = true
  }
}


resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "Podinfo-Lambda-High-Error-Rate"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60" # 1 minute
  statistic           = "Sum"
  threshold           = "5" # More than 5 errors in 1 minute
  alarm_description   = "Triggers a rollback if the new Lambda version has excessive errors."
  dimensions = {
    FunctionName = aws_lambda_function.podinfo.function_name
    Resource     = "${aws_lambda_function.podinfo.function_name}:${aws_lambda_alias.live.name}"
  }
}
