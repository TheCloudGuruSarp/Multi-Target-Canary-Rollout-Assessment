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

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_ecr_access" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_lambda_function" "podinfo" {
  function_name = "podinfo-lambda"
  role          = aws_iam_role.lambda_exec_role.arn
  package_type  = "Image"
  timeout       = 30 // seconds

  image_uri = "public.ecr.aws/lambda/python:3.9"
  publish = true
}

resource "aws_lambda_alias" "live" {
  name             = "live"
  function_name    = aws_lambda_function.podinfo.function_name
  function_version = aws_lambda_function.podinfo.version
}

resource "aws_apigatewayv2_api" "http_api" {
  name          = "podinfo-lambda-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_alias.live.invoke_arn // Point to the alias, not the function
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.podinfo.function_name
  qualifier     = aws_lambda_alias.live.name // Important: Permission is for the alias
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*"
}

resource "aws_iam_role_policy_attachment" "lambda_secret_access" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite" # Note: In production, create a read-only policy!
}
