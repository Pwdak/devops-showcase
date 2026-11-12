terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend distant : état chiffré dans S3 + verrouillage DynamoDB.
  # Bucket / table / région sont fournis à l'init (ils dépendent du compte) :
  #   terraform init -backend-config=backend.hcl
  backend "s3" {
    key     = "prod/infrastructure.tfstate"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# AMI Amazon Linux 2023 la plus récente (plus d'ID codé en dur)
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Dépôt ECR créé par le bootstrap
data "aws_ecr_repository" "app" {
  name = var.ecr_repository_name
}

# 1. Réseau (VPC, sous-réseaux, IGW, NAT)
module "vpc" {
  source               = "./modules/vpc"
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  db_subnet_cidrs      = var.db_subnet_cidrs
}

# 2. Sécurité (Security Groups, moindre privilège)
module "security" {
  source   = "./modules/security"
  vpc_id   = module.vpc.vpc_id
  vpc_cidr = var.vpc_cidr
}

# 3. Calcul et base de données (ALB, ASG, RDS)
module "compute_db" {
  source       = "./modules/compute_db"
  project_name = var.project_name
  aws_region   = var.aws_region

  vpc_id          = module.vpc.vpc_id
  public_subnets  = module.vpc.public_subnet_ids
  private_subnets = module.vpc.private_subnet_ids
  db_subnets      = module.vpc.db_subnet_ids
  alb_sg_id       = module.security.alb_sg_id
  ec2_sg_id       = module.security.ec2_sg_id
  db_sg_id        = module.security.db_sg_id

  ami_id               = data.aws_ssm_parameter.al2023_ami.value
  instance_type        = var.instance_type
  asg_min_size         = var.asg_min_size
  asg_max_size         = var.asg_max_size
  asg_desired_capacity = var.asg_desired_capacity

  ecr_repository_url = data.aws_ecr_repository.app.repository_url
  image_tag          = var.image_tag
  git_repo_url       = var.git_repo_url
  git_ref            = var.git_ref

  certificate_arn        = local.https_enabled ? aws_acm_certificate_validation.app[0].certificate_arn : ""
  db_multi_az            = var.db_multi_az
  db_instance_class      = var.db_instance_class
  db_deletion_protection = var.db_deletion_protection
  db_skip_final_snapshot = var.db_skip_final_snapshot
}
