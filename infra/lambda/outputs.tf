output "api_endpoint" {
  description = "The base URL endpoint for the API Gateway"
  value       = aws_apigatewayv2_api.http_api.api_endpoint
}
