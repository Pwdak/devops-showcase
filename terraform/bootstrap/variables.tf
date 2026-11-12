variable "aws_region" {
  description = "Région AWS"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Préfixe des ressources"
  type        = string
  default     = "devops-showcase"
}

variable "github_org" {
  description = "Utilisateur ou organisation GitHub propriétaire du dépôt"
  type        = string
}

variable "github_repo" {
  description = "Nom du dépôt GitHub"
  type        = string
}

variable "ecr_repository_name" {
  description = "Nom du dépôt ECR de l'application"
  type        = string
  default     = "devops-showcase-app"
}

variable "create_github_oidc_provider" {
  description = "Mettre false si le fournisseur OIDC GitHub existe déjà dans le compte"
  type        = bool
  default     = true
}
