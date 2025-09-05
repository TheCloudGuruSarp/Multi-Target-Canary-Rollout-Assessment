// Output the DNS name of the ALB so we can easily access it after deployment.
output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}
