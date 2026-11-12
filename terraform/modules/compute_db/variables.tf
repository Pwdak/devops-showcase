variable "project_name" {
  description = "Préfixe de nommage"
  type        = string
  default     = "devops-showcase"
}

variable "aws_region" {
  description = "Région AWS (injectée dans la configuration des instances)"
  type        = string
}

variable "vpc_id" {
  description = "ID du VPC"
  type        = string
}

variable "public_subnets" {
  description = "Sous-réseaux publics (ALB)"
  type        = list(string)
}

variable "private_subnets" {
  description = "Sous-réseaux privés (instances de l'ASG)"
  type        = list(string)
}

variable "db_subnets" {
  description = "Sous-réseaux isolés (RDS)"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security Group de l'ALB"
  type        = string
}

variable "ec2_sg_id" {
  description = "Security Group des instances"
  type        = string
}

variable "db_sg_id" {
  description = "Security Group de la base"
  type        = string
}

variable "ami_id" {
  description = "AMI Amazon Linux 2023"
  type        = string
}

variable "instance_type" {
  description = "Type d'instance EC2"
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  type    = number
  default = 2
}

variable "asg_max_size" {
  type    = number
  default = 4
}

variable "asg_desired_capacity" {
  type    = number
  default = 2
}

variable "cpu_target_percent" {
  description = "Seuil CPU moyen déclenchant le scale-out"
  type        = number
  default     = 70
}

variable "certificate_arn" {
  description = "Certificat ACM. Vide = HTTP uniquement"
  type        = string
  default     = ""
}

variable "ecr_repository_url" {
  description = "URL du dépôt ECR (registre/nom)"
  type        = string
}

variable "image_tag" {
  description = "Tag de l'image Docker à déployer (SHA du commit)"
  type        = string
}

variable "git_repo_url" {
  description = "URL du dépôt Git contenant le playbook Ansible (ansible-pull)"
  type        = string
}

variable "git_ref" {
  description = "Branche/tag/commit du playbook Ansible"
  type        = string
  default     = "main"
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type    = string
  default = "cloudadmin"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_multi_az" {
  type    = bool
  default = true
}

variable "db_deletion_protection" {
  type    = bool
  default = false
}

variable "db_skip_final_snapshot" {
  type    = bool
  default = true
}

variable "log_retention_days" {
  type    = number
  default = 7
}
