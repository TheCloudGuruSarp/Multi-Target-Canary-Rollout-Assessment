resource "aws_ecr_repository" "podinfo" {
  name                 = "podinfo"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = ["6938fd4d9c6d15aaa29c34eBCb858ddc39a03d97"]
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:TheCloudGuruSarp/Multi-Target-Canary-Rollout-Assessment:*"] // IMPORTANT: Change this line
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}
resource "aws_secretsmanager_secret" "app_secret" {
  name = "/dockyard/SUPER_SECRET_TOKEN"
  description = "Super secret token for the Podinfo application"
}

resource "aws_secretsmanager_secret_version" "app_secret_v1" {
  secret_id     = aws_secretsmanager_secret.app_secret.id
  secret_string = "initial-super-secret-value-12345"
}
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "Podinfo-Multi-Target-Dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric",
        x      = 0,
        y      = 0,
        width  = 24,
        height = 6,
        properties = {
          title  = "ALB & API Gateway - Request Count & 5xx Errors",
          view   = "timeSeries",
          stacked = false,
          region = "us-east-1",
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "podinfo-alb", { label = "ALB Requests" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { label = "ALB 5xx Errors", yAxis = "right" }],
            ["AWS/ApiGateway", "Count", "ApiName", "podinfo-lambda-api", { label = "API GW Requests" }],
            [".", "5xx", ".", ".", { label = "API GW 5xx Errors", yAxis = "right" }]
          ]
        }
      },
      {
        type   = "metric",
        x      = 0,
        y      = 6,
        width  = 12,
        height = 6,
        properties = {
          title  = "Lambda Performance",
          view   = "timeSeries",
          stacked = false,
          region = "us-east-1",
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", "podinfo-lambda", { stat = "p95", label = "Duration (p95)" }],
            [".", "Errors", ".", ".", { yAxis = "right", stat = "Sum", label = "Errors" }],
            [".", "Throttles", ".", ".", { yAxis = "right", stat = "Sum", label = "Throttles" }]
          ]
        }
      },
      {
        type   = "metric",
        x      = 12,
        y      = 6,
        width  = 12,
        height = 6,
        properties = {
          title  = "EC2 Host Metrics (Avg)",
          view   = "timeSeries",
          stacked = false,
          region = "us-east-1",
          metrics = [
            // CORRECTED METRIC DEFINITIONS FOR CWAGENT
            ["CWAgent", "cpu_usage_active", "AutoScalingGroupName", "podinfo-asg", { label = "CPU Usage %", stat = "Average" }],
            ["CWAgent", "mem_used_percent", "AutoScalingGroupName", "podinfo-asg", { label = "Memory Used %", stat = "Average" }]
          ]
        }
      }
    ]
  })
}
