# Valeurs NON secrètes (aucun mot de passe ici : RDS gère le sien).
aws_region               = "eu-west-1"
project_name             = "devops-showcase"
environment              = "prod"
instance_type            = "t3.micro"
db_backup_retention_days = 1

# TODO : remplacer par l'URL de VOTRE dépôt GitHub (public).
# Le pipeline la surcharge automatiquement via -var.
git_repo_url = "https://github.com/Pwdak/devops-showcase.git"

# Optionnel : HTTPS + domaine Route 53
# domain_name     = "demo.example.com"
# route53_zone_id = "Z0123456789ABC"
