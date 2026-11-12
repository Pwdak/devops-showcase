variable "vpc_id" {
  description = "ID du VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR du VPC (restreint le trafic sortant vers la base)"
  type        = string
}

variable "app_port" {
  description = "Port de l'application conteneurisée"
  type        = number
  default     = 8080
}
