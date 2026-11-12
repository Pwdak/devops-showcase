.PHONY: help test lint fmt validate docker-build docker-run

help:
	@echo "make test | lint | fmt | validate | docker-build | docker-run"

test:
	cd app && npm ci && npm test

lint:
	cd app && npm run lint
	cd ansible && ansible-lint .

fmt:
	terraform -chdir=terraform fmt -recursive

validate:
	terraform -chdir=terraform init -backend=false && terraform -chdir=terraform validate

docker-build:
	docker build -t devops-showcase-app:local ./app

docker-run: docker-build
	docker run --rm -p 8080:8080 -e IMDS_DISABLED=true devops-showcase-app:local
