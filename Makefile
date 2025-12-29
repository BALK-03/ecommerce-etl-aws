.ONESHELL:
SHELL := /bin/bash

.PHONY: setup-terraform deploy-assets query-athena uv-setup deploy destroy-infra

# Load environment variables
ifneq ("$(wildcard .env)","")
    include .env
    export $(shell sed 's/=.*//' .env)
endif

setup-terraform:
	@echo "--- Initializing Infrastructure ---"
	@cd infra && terraform init && terraform apply -auto-approve

deploy-assets:
	@echo "--- Uploading Glue Scripts & Assets ---"
	@bash scripts/deploy_assets.sh

query-athena:
	@echo "--- Running Validation Query ---"
	@.venv/bin/python3 utils/athena_query.py
	
uv-setup:
	@echo "--- Installing uv & Syncing Dependencies ---"
	@if command -v yum >/dev/null; then sudo yum install -y curl; \
	 elif command -v apt-get >/dev/null; then sudo apt-get install -y curl; fi
	@curl -LsSf https://astral.sh/uv/install.sh | sh
	@export PATH="$(HOME)/.local/bin:$$PATH" && uv venv && uv sync


deploy: uv-setup setup-terraform deploy-assets
	@echo "Full Deployment Complete"

destroy-infra:
	@echo "Destroying Infrastructure"
	@cd infra && terraform destroy -auto-approve