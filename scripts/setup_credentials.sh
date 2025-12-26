#!/bin/bash
set -e

echo "Enter your AWS Access Key ID:"
read AWS_ACCESS_KEY_ID
echo "Enter your AWS Secret Access Key:"
read AWS_SECRET_ACCESS_KEY
echo "Default AWS Region is us-east-1."

aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
aws configure set region us-east-1

echo "AWS credentials configured! You can now run Terraform."
