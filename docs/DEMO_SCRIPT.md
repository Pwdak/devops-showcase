# Script de démo (10 minutes) et questions d'entretien

## Avant l'entretien (la veille)

- Déployez l'infrastructure (le premier apply dure ~20 min) et vérifiez `/health`.
- Préparez 4 onglets : repo GitHub, dernier run Actions, console AWS (VPC/EC2/ASG), page de l'application.
- Détruisez après l'entretien.

## Déroulé

| Min | Action | Message clé |
| :--- | :--- | :--- |
| 0-2 | Diagramme du README | « Trois couches réseau, deux AZ, chaque couche n'accepte que la précédente. » |
| 2-4 | Arborescence Terraform | « Modules réutilisables, backend distant verrouillé, bootstrap séparé. » |
| 4-6 | Run du pipeline | « fmt, validate, tflint, tfsec, ansible-lint, Trivy, apply : tout est automatisé, sans clé AWS grâce à l'OIDC. » |
| 6-8 | Page de l'app + boucle `curl` | « L'ALB répartit entre les AZ. » |
| 8-10 | **Terminer une instance en direct** | « Aucune coupure ; l'ASG la remplace et le remplaçant se configure seul via ansible-pull. » |

## Questions probables et éléments de réponse

**Pourquoi Terraform ET Ansible ?** Terraform provisionne les ressources (réseau, ALB, RDS) de façon déclarative ; Ansible configure l'intérieur des machines (durcissement, Docker, service applicatif).

**Pourquoi `ansible-pull` plutôt qu'un push SSH ?** Les instances sont privées et éphémères. Avec un push, une instance recréée par l'ASG ne serait jamais configurée. En pull, chaque instance se configure au démarrage à la révision exacte du commit.

**Pourquoi OIDC ?** Pas de clé longue durée à stocker ni à faire tourner ; le rôle n'est assumable que par ce dépôt.

**Où est le mot de passe de la base ?** Nulle part dans le code : RDS le génère et le stocke dans Secrets Manager (avec rotation) ; l'application le lit à l'exécution grâce au rôle IAM de l'instance.

**Pourquoi un health check `/health` sans base de données ?** Pour qu'une panne de la base ne retire pas toutes les instances du load balancer.

**Comment déployez-vous sans interruption ?** Instance refresh rolling avec `min_healthy 100 %` / `max 200 %` : une instance saine est lancée avant d'en retirer une ancienne.

**Limites assumées ?** Une seule NAT Gateway (coût, point de défaillance unique), rôle CI en `AdministratorAccess` (démo), TLS RDS sans validation de CA, pas d'alarmes. Je sais comment les corriger : une NAT par AZ, rôles plan/apply séparés avec politique minimale, bundle CA RDS, CloudWatch + SNS.

**Comment ajouteriez-vous un environnement staging ?** Un répertoire/workspace par environnement avec sa propre clé d'état, mêmes modules, variables différentes.

**Comment gérez-vous les secrets applicatifs supplémentaires ?** Secrets Manager ou SSM Parameter Store, lus au runtime via IAM, jamais en variable d'environnement ni dans Git.
