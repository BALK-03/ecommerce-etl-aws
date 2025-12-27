#!/bin/bash
set -e

cd infra
echo "Initializing Terraform..."
terraform init
echo "Applying auto-approved configurations..."
terraform apply -auto-approve
cd ..
