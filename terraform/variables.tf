variable "aws_region" {
  description = "Région AWS"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Préfixe de nommage et tag Project"
  type        = string
  default     = "devops-showcase"
}

variable "environment" {
  description = "Nom de l'environnement"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR du VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Les 2 zones de disponibilité utilisées"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "db_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.21.0/24", "10.0.22.0/24"]
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

variable "ecr_repository_name" {
  description = "Nom du dépôt ECR (créé par le bootstrap)"
  type        = string
  default     = "devops-showcase-app"
}

variable "image_tag" {
  description = "Tag de l'image à déployer (SHA du commit, fourni par le pipeline)"
  type        = string

  validation {
    condition     = length(var.image_tag) > 0
    error_message = "image_tag ne peut pas être vide."
  }
}

variable "git_repo_url" {
  description = "URL HTTPS du dépôt public contenant le playbook Ansible"
  type        = string
}

variable "git_ref" {
  description = "Révision Git du playbook (le pipeline passe le SHA du commit)"
  type        = string
  default     = "main"
}

variable "domain_name" {
  description = "Nom de domaine de l'application (optionnel, active HTTPS)"
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Zone Route 53 hébergeant domain_name (optionnel)"
  type        = string
  default     = ""
}

variable "db_multi_az" {
  type    = bool
  default = true
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_deletion_protection" {
  type    = bool
  default = false
}

variable "db_skip_final_snapshot" {
  type    = bool
  default = true
}
