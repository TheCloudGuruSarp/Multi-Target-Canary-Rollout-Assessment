// --- IAM Role for Lambda Function ---
// This role grants the Lambda function permissions to run and access other AWS services.
resource "aws_iam_role" "lambda_exec_role" {
  name = "podinfo-lambda-execution-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

// Attach necessary policies for logging to CloudWatch and pulling images from ECR.
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_ecr_access" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

// --- Lambda Function ---
// Defines the Lambda function, configured to run from a container image.
resource "aws_lambda_function" "podinfo" {
  function_name = "podinfo-lambda"
  role          = aws_iam_role.lambda_exec_role.arn
  package_type  = "Image"
  timeout       = 30 // seconds

  // For the initial setup, we use a public placeholder image.
  // Our CI/CD pipeline will replace this with our own custom-built image URI during deployment.
  image_uri = "public.ecr.aws/lambda/python:3.9"
  // 'publish = true' creates a new, numbered version of the function each time it's updated.
  // This is required for CodeDeploy to manage versions.
  publish = true
}

// --- Lambda Alias ---
// A Lambda alias is a pointer to a specific function version.
// CodeDeploy performs traffic shifting by updating the weights on this alias.
resource "aws_lambda_alias" "live" {
  name             = "live"
  function_name    = aws_lambda_function.podinfo.function_name
  function_version = aws_lambda_function.podinfo.version
}

// --- API Gateway (HTTP API) ---
// A lightweight, low-cost API Gateway to act as the HTTP front door for our Lambda.
resource "aws_apigatewayv2_api" "http_api" {
  name          = "podinfo-lambda-api"
  protocol_type = "HTTP"
}

// The integration connects a route in our API to the Lambda function.
resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_alias.live.invoke_arn // Point to the alias, not the function
}

// A default route that catches all requests ($default) and sends them to our Lambda integration.
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

// This permission allows API Gateway to invoke our Lambda function.
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.podinfo.function_name
  qualifier     = aws_lambda_alias.live.name // Important: Permission is for the alias
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*"
}
# Add this inside infra/lambda/main.tf

# We need to grant the Lambda execution role permission to read the secret.
resource "aws_iam_role_policy_attachment" "lambda_secret_access" {
  role       = aws_iam_role.lambda_exec_role.name
  # This is a managed policy, but for fine-grained control, you'd create your own
  # similar to the EC2 stack. For simplicity, we'll attach a broad permission here.
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite" # Note: In production, create a read-only policy!
}
