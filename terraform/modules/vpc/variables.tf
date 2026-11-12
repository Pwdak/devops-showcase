variable "vpc_cidr" {
  description = "Le bloc CIDR principal pour le VPC"
  type        = string
}

variable "availability_zones" {
  description = "Liste des zones de disponibilité (AZ) à utiliser"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Blocs CIDR pour les sous-réseaux publics"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Blocs CIDR pour les sous-réseaux privés applicatifs"
  type        = list(string)
}

variable "db_subnet_cidrs" {
  description = "Blocs CIDR pour les sous-réseaux privés de la base de données"
  type        = list(string)
}