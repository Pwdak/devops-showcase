# Cloud-Native DevOps Showcase

Infrastructure AWS **hautement disponible, sécurisée et entièrement automatisée** : réseau multi-AZ, Auto Scaling, RDS Multi-AZ, déployée par **Terraform**, configurée par **Ansible**, livrée par un pipeline **GitHub Actions** sans aucune clé AWS statique.

![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC) ![Ansible](https://img.shields.io/badge/Config-Ansible-EE0000) ![Docker](https://img.shields.io/badge/Container-Docker-2496ED) ![AWS](https://img.shields.io/badge/Cloud-AWS-FF9900) ![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF)

## Architecture

```mermaid
flowchart TB
    user([Internet]) --> alb
    subgraph VPC["VPC 10.0.0.0/16 - ca-central-1"]
        subgraph pub["Sous-réseaux publics (AZ a / AZ b)"]
            alb[Application Load Balancer]
            nat[NAT Gateway]
        end
        subgraph priv["Sous-réseaux privés (AZ a / AZ b)"]
            asg["Auto Scaling Group<br/>EC2 + Docker (min 2 / max 4)"]
        end
        subgraph data["Sous-réseaux données isolés"]
            rds[("RDS PostgreSQL<br/>Multi-AZ")]
        end
        alb -->|8080| asg
        asg -->|5432| rds
        asg -->|sortie HTTPS| nat
    end
    gh[GitHub Actions] -->|OIDC| aws[(AWS API)]
    gh -->|push image| ecr[(Amazon ECR)]
    asg -->|pull image| ecr
    asg -->|ansible-pull| repo[(Dépôt Git)]
    asg -->|lit le mot de passe| sm[Secrets Manager]
```

## Flux de déploiement

```mermaid
flowchart LR
    A[git push main] --> B[Lint + tests<br/>fmt / validate / tflint / tfsec / ansible-lint]
    B --> C[Docker build]
    C --> D[Scan Trivy]
    D --> E[Push ECR<br/>tag = SHA du commit]
    E --> F[terraform apply]
    F --> G[Instance refresh<br/>rolling, 0 downtime]
    G --> H[ansible-pull<br/>sur chaque instance]
    H --> I[Smoke test]
```

## Choix d'architecture (et pourquoi)

| Décision | Justification |
| :--- | :--- |
| **Backend S3 + DynamoDB** | État partagé, chiffré, versionné, avec verrouillage : travail en équipe sûr. |
| **Bootstrap séparé** | Résout le problème de l'oeuf et de la poule (le backend ne peut pas se créer lui-même). |
| **3 niveaux de sous-réseaux** | Public (ALB/NAT), privé (app), isolé (BDD, aucune route Internet). |
| **Security Groups chaînés** | Internet → ALB → EC2 → RDS. Chaque couche n'accepte que la précédente. |
| **OIDC GitHub → AWS** | Aucune clé d'accès stockée : identifiants temporaires, rôle limité à ce dépôt. |
| **Mot de passe RDS géré par AWS** | Généré, stocké dans Secrets Manager et rotaté : il n'existe ni dans Git ni dans le pipeline. L'app le lit via son rôle IAM. |
| **IMDSv2 obligatoire** | Protège les credentials de l'instance contre les attaques SSRF. |
| **`ansible-pull` au boot** | Les instances sont privées et éphémères : toute instance recréée par l'ASG se configure seule, sans SSH ni intervention du pipeline. |
| **Tags d'image immuables (SHA)** | Chaque déploiement est traçable et reproductible ; pas de `latest`. |
| **Accès via SSM, pas de SSH** | Aucun port 22 ouvert, aucune clé à gérer. |
| **Health check `/health` indépendant de la BDD** | Une panne RDS ne vide pas le load balancer. |

## Structure du dépôt

```text
.github/workflows/    deploy.yml (CI/CD) · destroy.yml (nettoyage manuel)
terraform/
  bootstrap/          backend S3+DynamoDB, ECR, OIDC GitHub (exécuté une seule fois)
  modules/vpc/        VPC, sous-réseaux, IGW, NAT, flow logs
  modules/security/   Security Groups (moindre privilège)
  modules/compute_db/ ALB, ASG, launch template, IAM, RDS
  main.tf dns.tf ...  composition + HTTPS/Route 53 optionnel
ansible/
  playbook.yml        exécuté par ansible-pull sur chaque instance
  roles/              hardening · docker-setup · app-deploy
app/                  API Node.js (Express) + Dockerfile multi-étapes
docs/                 guide de déploiement · script de démo
```

## Démarrage rapide

Voir **[docs/DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md)** pour la procédure complète pas à pas.

```bash
# 1. Bootstrap (une seule fois)
cd terraform/bootstrap
terraform init && terraform apply -var github_org=MON_COMPTE -var github_repo=MON_DEPOT

# 2. Renseigner les variables GitHub (AWS_ROLE_ARN, TF_STATE_BUCKET) puis :
git push origin main    # le pipeline fait le reste
```

## Critères de validation

- [x] **Zéro intervention manuelle** après le bootstrap : réseau → application, tout est piloté par Terraform et le pipeline.
- [x] **Haute disponibilité** : arrêt forcé d'une instance → l'ASG (health check ELB) la remplace, l'ALB continue de servir via l'autre AZ. *(procédure de test dans le guide)*
- [x] **Sécurité réseau** : instances et base sans IP publique, tout passe par l'ALB ; accès d'administration via SSM.
- [x] **DevSecOps** : tfsec, TFLint, ansible-lint, Trivy, IMDSv2, chiffrement EBS/RDS/S3, flow logs.

## Coût

Ordre de grandeur de **3 à 5 USD par jour** quand l'infrastructure tourne (NAT Gateway, ALB, RDS Multi-AZ, 2 instances), à vérifier avec l'AWS Pricing Calculator. **Détruisez après chaque démo** (workflow `Destroy infrastructure`).

## Améliorations envisagées

- Une NAT Gateway par AZ (ici une seule, pour limiter les coûts : point de défaillance unique assumé).
- Rôles IAM séparés plan (lecture seule) / apply, avec politique sur mesure au lieu d'`AdministratorAccess`.
- Bundle CA RDS avec validation TLS stricte côté application.
- Alarmes CloudWatch + SNS, WAF devant l'ALB, VPC endpoints pour réduire le trafic NAT.
