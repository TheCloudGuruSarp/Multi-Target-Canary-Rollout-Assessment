// --- IAM Role for CodeDeploy ---
// This role grants CodeDeploy permissions to manage Lambda function versions and aliases.
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

// --- CodeDeploy Application ---
resource "aws_codedeploy_app" "lambda_app" {
  name             = "podinfo-lambda"
  compute_platform = "Lambda"
}

// --- CodeDeploy Deployment Group ---
// Defines the canary deployment strategy for our Lambda function.
resource "aws_codedeploy_deployment_group" "lambda_dg" {
  app_name              = aws_codedeploy_app.lambda_app.name
  deployment_group_name = "podinfo-lambda-canary-dg"
  service_role_arn      = aws_iam_role.codedeploy_lambda_role.arn

  // This pre-defined configuration shifts 10% of traffic to the new version for 5 minutes.
  deployment_config_name = "CodeDeployDefault.LambdaCanary10Percent5Minutes"

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN" // For Lambda, this enables canary or linear deployments
  }

  // Tells CodeDeploy which Lambda function and alias to manage.
  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  lambda_function_info {
    function_name = aws_lambda_function.podinfo.function_name
    function_alias = aws_lambda_alias.live.name
  }

  // Automatically roll back if a deployment fails.
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}
