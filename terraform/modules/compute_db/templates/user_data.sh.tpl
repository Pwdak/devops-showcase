#!/bin/bash
# Exécuté au premier démarrage de CHAQUE instance (ASG compris).
# Logs : /var/log/user-data.log et /var/log/cloud-init-output.log
set -euxo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

export HOME=/root
export PATH=$PATH:/usr/local/bin

retry() {
  for attempt in 1 2 3 4 5; do
    "$@" && return 0
    echo "Tentative $attempt échouée : $*" >&2
    sleep 15
  done
  return 1
}

# Variables transmises à Ansible (aucun secret : le mot de passe de la base
# est lu par l'application dans Secrets Manager via le rôle IAM).
cat > /etc/devops-showcase-vars.yml <<'VARS'
aws_region: "${aws_region}"
ecr_registry: "${ecr_registry}"
ecr_repository: "${ecr_repository}"
image_tag: "${image_tag}"
db_host: "${db_host}"
db_name: "${db_name}"
db_secret_arn: "${db_secret_arn}"
app_log_group: "${log_group}"
VARS
chmod 0640 /etc/devops-showcase-vars.yml

retry dnf install -y git python3-pip
retry pip3 install --no-cache-dir "ansible-core==2.15.13"

# Configuration de la machine depuis le dépôt Git, à la révision exacte
# du commit déployé.
retry ansible-pull \
  --url "${git_repo_url}" \
  --checkout "${git_ref}" \
  --directory /opt/ansible-pull \
  --inventory localhost, \
  --extra-vars @/etc/devops-showcase-vars.yml \
  ansible/playbook.yml
