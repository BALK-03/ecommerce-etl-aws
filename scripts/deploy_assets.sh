#!/bin/bash
set -e

ASSETS_BUCKET="badr-glue-assets-us-east-1"

echo "Deploying Assets to S3..."

echo "Updating Spark scripts..."
aws s3 cp src/glue/jobs/silver.py s3://${ASSETS_BUCKET}/scripts/silver.py
aws s3 cp src/glue/jobs/gold.py s3://${ASSETS_BUCKET}/scripts/gold.py

echo "Packaging schemas..."
cd src/glue/ && zip -r ../../schemas.zip schemas/ > /dev/null && cd ../../
aws s3 cp schemas.zip s3://${ASSETS_BUCKET}/libs/schemas.zip
rm schemas.zip

echo "Assets Deployed. The Glue Workflow will pick up these changes on its next run."