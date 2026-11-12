output "alb_dns_name" {
  description = "Nom DNS public de l'ALB"
  value       = aws_lb.app.dns_name
}

output "alb_zone_id" {
  description = "Zone ID de l'ALB (alias Route 53)"
  value       = aws_lb.app.zone_id
}

output "asg_name" {
  description = "Nom de l'Auto Scaling Group"
  value       = aws_autoscaling_group.app.name
}

output "db_endpoint" {
  description = "Adresse de la base RDS"
  value       = aws_db_instance.postgres.address
}

output "db_secret_arn" {
  description = "Secret Secrets Manager contenant les identifiants de la base"
  value       = aws_db_instance.postgres.master_user_secret[0].secret_arn
}

output "app_log_group" {
  description = "Groupe de logs CloudWatch de l'application"
  value       = aws_cloudwatch_log_group.app.name
}
