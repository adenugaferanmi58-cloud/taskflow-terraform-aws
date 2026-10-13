output "app_url" {
  description = "Open this in a browser"
  value       = "http://${aws_lb.app.dns_name}"
}

output "db_endpoint" {
  value = aws_db_instance.main.address
}