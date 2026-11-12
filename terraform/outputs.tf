output "alb_dns_name" {
  description = "DNS public de l'ALB"
  value       = module.compute_db.alb_dns_name
}

output "app_url" {
  description = "URL de l'application"
  value       = local.https_enabled ? "https://${var.domain_name}" : "http://${module.compute_db.alb_dns_name}"
}

output "asg_name" {
  description = "Nom de l'Auto Scaling Group"
  value       = module.compute_db.asg_name
}

output "rds_endpoint" {
  description = "Endpoint RDS (privé, non joignable depuis Internet)"
  value       = module.compute_db.db_endpoint
}

output "app_log_group" {
  description = "Groupe de logs CloudWatch"
  value       = module.compute_db.app_log_group
}
