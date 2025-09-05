// --- Elastic Container Registry (ECR) ---
// ECR repository to store our podinfo container images.
// Tag immutability prevents overwriting an image tag, which is a best practice.
resource "aws_ecr_repository" "podinfo" {
  name                 = "podinfo"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

// --- IAM & OIDC for GitHub Actions ---
// OIDC provider for GitHub Actions to enable passwordless authentication.
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = ["6938fd4d9c6d15aaa29c34eBCb858ddc39a03d97"]
}

// IAM policy document that specifies the trust relationship.
// It allows entities from our specific GitHub repo to assume this role.
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
      values   = ["repo:KULLANICI_ADINIZ/REPO_ADINIZ:*"] // IMPORTANT: Change this line
    }
  }
}

// The IAM role that GitHub Actions will assume.
resource "aws_iam_role" "github_actions" {
  name               = "github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}

// Attach a policy to the role.
// For now, we'll grant power user access to ECR. This can be scoped down later.
resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}
# --- Secrets Manager ---
# The secret that our application will use.
resource "aws_secretsmanager_secret" "app_secret" {
  name = "/dockyard/SUPER_SECRET_TOKEN"
  description = "Super secret token for the Podinfo application"
}

# The initial value for our secret.
resource "aws_secretsmanager_secret_version" "app_secret_v1" {
  secret_id     = aws_secretsmanager_secret.app_secret.id
  secret_string = "initial-super-secret-value-12345"
}

# --- CloudWatch Dashboard ---
# A unified dashboard to monitor the health of both EC2 and Lambda targets.
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
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "podinfo-alb", { label = "ALB Requests" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { label = "ALB 5xx Errors", yAxis = "right" }],
            ["AWS/ApiGateway", "Count", "ApiName", "podinfo-lambda-api", { label = "API GW Requests" }],
            [".", "5xx", ".", ".", { label = "API GW 5xx Errors", yAxis = "right" }]
          ],
          region = "us-east-1"
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
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", "podinfo-lambda", { stat = "p95" }],
            [".", "Errors", ".", ".", { yAxis = "right", stat = "Sum" }],
            [".", "Throttles", ".", ".", { yAxis = "right", stat = "Sum" }]
          ],
          region = "us-east-1"
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
          metrics = [
            ["CWAgent", "cpu_usage_idle", "AutoScalingGroupName", "podinfo-asg", "ImageId", "*", "InstanceId", "*", "InstanceType", "*", { label = "CPU Idle", invert = true }],
            ["CWAgent", "mem_used_percent", "AutoScalingGroupName", "podinfo-asg", "ImageId", "*", "InstanceId", "*", "InstanceType", "*", { label = "Memory Used %" }]
          ],
          region = "us-east-1"
        }
      }
    ]
  })
}
