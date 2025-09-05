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
