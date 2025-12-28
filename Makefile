.PHONY: exp-env-var aws-login setup-terraform deploy-assets query-athena uv-setup full-deploy destroy-infra

exp-env-var:
	@set -a && . .env && set +a && echo "Environment variables loaded"

aws-login:
	@bash scripts/aws_login.sh

setup-terraform:
	@bash scripts/setup_terraform.sh

destroy-infra:
	@cd infra && terraform destroy -auto-approve

deploy-assets:
	@bash scripts/deploy_assets.sh

query-athena:
	@python3 utils/athena_query.py

uv-setup:
	@sudo apt install -y curl && \
	curl -LsSf https://astral.sh/uv/install.sh | sh && \
	uv venv .venv && \
	. .venv/bin/activate && \
	uv sync

full-deploy:
	@bash scripts/aws_login.sh && bash scripts/setup_terraform.sh
