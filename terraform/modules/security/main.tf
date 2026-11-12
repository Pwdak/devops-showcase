# ALB : seul point d'entrée depuis Internet (HTTP/HTTPS)
resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Application Load Balancer - public HTTP/HTTPS"
  vpc_id      = var.vpc_id

  tags = { Name = "alb-sg" }
}

#tfsec:ignore:aws-ec2-no-public-ingress-sgr
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP depuis Internet (redirige vers HTTPS si active)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

#tfsec:ignore:aws-ec2-no-public-ingress-sgr
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS depuis Internet"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Vers les instances applicatives uniquement"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.ec2.id
}

# Instances applicatives : accessibles UNIQUEMENT depuis l'ALB
resource "aws_security_group" "ec2" {
  name        = "ec2-app-sg"
  description = "Instances applicatives privees"
  vpc_id      = var.vpc_id

  tags = { Name = "ec2-app-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "ec2_from_alb" {
  security_group_id            = aws_security_group.ec2.id
  description                  = "Port applicatif depuis l'ALB uniquement"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.alb.id
}

#tfsec:ignore:aws-ec2-no-public-egress-sgr
resource "aws_vpc_security_group_egress_rule" "ec2_https_out" {
  security_group_id = aws_security_group.ec2.id
  description       = "HTTPS sortant via NAT (ECR, SSM, Secrets Manager, GitHub, dnf)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "ec2_to_db" {
  security_group_id = aws_security_group.ec2.id
  description       = "PostgreSQL vers le VPC"
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
  cidr_ipv4         = var.vpc_cidr
}

# RDS : accessible UNIQUEMENT depuis les instances applicatives
resource "aws_security_group" "db" {
  name        = "rds-db-sg"
  description = "PostgreSQL - acces depuis les instances applicatives uniquement"
  vpc_id      = var.vpc_id

  tags = { Name = "rds-db-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_ec2" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL depuis les instances applicatives"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.ec2.id
}
