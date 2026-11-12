# Guide de déploiement pas à pas

Durée estimée : 1 h 30 (dont ~20 min d'attente AWS lors du premier déploiement).

## Phase 0 - Prérequis

| Outil | Vérification |
| :--- | :--- |
| Compte AWS avec facturation activée | console AWS |
| AWS CLI v2 | `aws --version` |
| Terraform >= 1.5 | `terraform version` |
| Git | `git --version` |
| Node.js 22 + Docker (tests locaux, optionnel) | `node -v` · `docker -v` |
| Compte GitHub | dépôt **public** (requis par `ansible-pull`) |

**Sécurité du compte** : activez le MFA sur le compte root, ne l'utilisez jamais au quotidien. Créez un utilisateur IAM Identity Center (ou IAM) avec droits administrateur pour le bootstrap, puis configurez le CLI :

```bash
aws configure          # ou : aws configure sso
aws sts get-caller-identity   # doit afficher votre compte
```

## Phase 1 - Dépôt GitHub

1. Créez un dépôt **public** vide sur GitHub (ex. `devops-showcase`).
2. Dans `terraform/terraform.tfvars`, remplacez `git_repo_url` par l'URL de votre dépôt.
3. Poussez le projet :

```bash
git init -b main
git add .
git commit -m "feat: initial DevOps showcase"
git remote add origin https://github.com/VOTRE_COMPTE/devops-showcase.git
# ne poussez pas encore : configurez d'abord AWS (phases 2-3)
```

> Vérifiez qu'aucun secret n'est versionné : `git status` ne doit lister ni `.tfstate`, ni `backend.hcl`.

## Phase 2 - Bootstrap AWS (une seule fois)

Crée le bucket d'état, la table de verrouillage, le dépôt ECR et le rôle OIDC.

```bash
cd terraform/bootstrap
terraform init
terraform apply -var github_org=VOTRE_COMPTE -var github_repo=devops-showcase
```

Notez les sorties : `tf_state_bucket`, `github_actions_role_arn`.

> Si l'erreur indique que le fournisseur OIDC existe déjà : ajoutez `-var create_github_oidc_provider=false`.

Conservez le fichier `terraform.tfstate` local du bootstrap (il est ignoré par Git).

## Phase 3 - Configurer GitHub

Dans le dépôt : **Settings → Secrets and variables → Actions → onglet Variables** :

| Variable | Valeur |
| :--- | :--- |
| `AWS_ROLE_ARN` | sortie `github_actions_role_arn` |
| `TF_STATE_BUCKET` | sortie `tf_state_bucket` |

Puis **Settings → Environments → New environment** : `production` (optionnel : ajoutez-y un *Required reviewer* pour une approbation manuelle avant chaque déploiement).

## Phase 4 - Test local avant de pousser

```bash
make test lint                 # app + ansible
make docker-run                # puis http://localhost:8080
cd terraform
cp backend.hcl.example backend.hcl   # éditer avec vos valeurs
terraform fmt -recursive
terraform init -backend=false && terraform validate
```

## Phase 5 - Premier déploiement

```bash
git push -u origin main
```

Suivez l'onglet **Actions**. Déroulé : validation → build/scan/push → `terraform apply` (RDS Multi-AZ : ~15 min) → instance refresh → smoke test.

À la fin, le job affiche l'URL ; elle est aussi dans les logs (`app_url`). Ouvrez-la : la page indique l'instance et l'AZ qui répondent. Rafraîchissez plusieurs fois : l'ALB alterne entre les 2 AZ.

Ensuite, **commitez `terraform/.terraform.lock.hcl`** (généré par un `terraform init` local) pour figer les versions de providers.

## Phase 6 - Vérifications

```bash
ALB=$(curl -s ...)   # ou copiez l'URL depuis le pipeline
curl -i http://$ALB/health          # 200
curl -s http://$ALB/api/info        # instanceId + AZ
curl -s http://$ALB/api/db          # {"database":"up"} : app -> RDS via Secrets Manager
```

Sécurité réseau : les instances n'ont pas d'IP publique (console EC2 → colonne *Public IPv4* vide) ; RDS est `publicly_accessible = false`.

Accès administrateur sans SSH (SSM) :

```bash
aws ssm start-session --target i-xxxxxxxxxxxx
sudo systemctl status app
sudo docker ps
tail -n 50 /var/log/user-data.log
```

Logs applicatifs : CloudWatch Logs → groupe `/devops-showcase/app`.

## Phase 7 - Test de haute disponibilité

1. Lancez en boucle une requête et observez les AZ :
   ```bash
   while true; do curl -s http://$ALB/api/info | grep -o '"availabilityZone":"[^"]*"'; sleep 1; done
   ```
2. Console EC2 : **terminez** une instance de l'ASG (*Terminate instance*).
3. Constatez : aucune erreur côté boucle (l'autre instance sert tout le trafic), puis l'ASG (health check ELB) lance un remplaçant qui se configure seul via `ansible-pull` (~3-5 min) et réapparaît dans la cible de l'ALB.

> Précision utile en entretien : l'ASG rééquilibre entre AZ ; en cas de panne d'une AZ entière, les remplaçants sont lancés dans l'AZ restante.

## Phase 8 - Test de scalabilité (CPU > 70 %)

Dans une session SSM sur chaque instance, saturez les 2 vCPU :

```bash
for i in 1 2; do (timeout 600 sh -c 'while :; do :; done' &); done
```

Après quelques minutes, CloudWatch montre la CPU moyenne > 70 % et l'ASG passe de 2 à 3-4 instances (Activity → ASG). La charge s'arrête seule après 10 minutes.

## Phase 9 - Mettre à jour l'application

Modifiez `app/src/app.js`, commitez, poussez : le pipeline rebuild, rescanne, publie une nouvelle image taguée par le SHA, et l'ASG remplace progressivement les instances **sans interruption** (nouvelle instance saine avant retrait de l'ancienne).

## Phase 10 - Détruire (important : coût)

GitHub → **Actions → Destroy infrastructure → Run workflow**, tapez `destroy`. (~10 min)

Le bootstrap (S3, DynamoDB, ECR, rôle) coûte quelques centimes par mois ; pour tout supprimer : vider le bucket (versions incluses) puis `terraform destroy` dans `bootstrap/` après avoir retiré `prevent_destroy`.

## Dépannage

| Symptôme | Piste |
| :--- | :--- |
| `terraform init` : bucket introuvable | variable `TF_STATE_BUCKET` incorrecte |
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | `github_org`/`github_repo` du bootstrap ne correspondent pas au dépôt, ou `AWS_ROLE_ARN` faux |
| Instances en boucle de remplacement | `ansible-pull` échoue : session SSM puis `cat /var/log/user-data.log` ; dépôt non public ou `git_repo_url` faux |
| `/api/db` renvoie 503 | secret illisible ou SG ; `sudo journalctl -u app -n 50` |
| Pipeline échoue sur Trivy | vulnérabilité critique corrigeable : mettre à jour l'image de base ou la dépendance |
| `tfsec` signale des alertes | `soft_fail: true` par défaut ; corriger puis passer à `false` |
| `InvalidClientTokenId` en local | `aws sts get-caller-identity` |
