output "alb_sg_id" {
  description = "Security Group de l'ALB"
  value       = aws_security_group.alb.id
}

output "ec2_sg_id" {
  description = "Security Group des instances applicatives"
  value       = aws_security_group.ec2.id
}

output "db_sg_id" {
  description = "Security Group de la base de données"
  value       = aws_security_group.db.id
}
