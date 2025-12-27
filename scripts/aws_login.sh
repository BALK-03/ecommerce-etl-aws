#!/bin/bash
set -e

echo "Enter your AWS Access Key ID:"
read AWS_ACCESS_KEY_ID
echo "Enter your AWS Secret Access Key:"
read AWS_SECRET_ACCESS_KEY
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=us-east-1

echo "AWS credentials set for this session"
aws sts get-caller-identity
