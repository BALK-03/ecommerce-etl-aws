#!/bin/bash
set -e

ASSETS_BUCKET="badr-glue-assets-us-east-1"
SILVER_JOB="silver_layer_job"
GOLD_JOB="gold_layer_job"
SILVER_CRAWLER="silver_orders_crawler"
GOLD_CRAWLER="gold_layer_crawler"


# Helpers
wait_for_job() {
    JOB_NAME=$1
    RUN_ID=$2
    echo "Waiting for Job: $JOB_NAME (Run ID: $RUN_ID)..."
    while true; do
        STATUS=$(aws glue get-job-run --job-name "$JOB_NAME" --run-id "$RUN_ID" --query 'JobRun.JobRunState' --output text)
        if [ "$STATUS" == "SUCCEEDED" ]; then
            echo "Job $JOB_NAME succeeded."
            break
        elif [ "$STATUS" == "FAILED" ] || [ "$STATUS" == "STOPPED" ] || [ "$STATUS" == "TIMEOUT" ]; then
            echo "Job $JOB_NAME failed with status: $STATUS"
            exit 1
        fi
        sleep 30
    done
}

wait_for_crawler() {
    CRAWLER_NAME=$1
    echo "Waiting for Crawler: $CRAWLER_NAME..."
    while true; do
        STATE=$(aws glue get-crawler --name "$CRAWLER_NAME" --query 'Crawler.State' --output text)
        if [ "$STATE" == "READY" ]; then
            # Verify the last crawl was successful
            LAST_STATUS=$(aws glue get-crawler --name "$CRAWLER_NAME" --query 'Crawler.LastCrawl.Status' --output text)
            if [ "$LAST_STATUS" == "SUCCEEDED" ]; then
                echo "Crawler $CRAWLER_NAME finished successfully."
                break
            else
                echo "Crawler $CRAWLER_NAME finished with error: $LAST_STATUS"
                exit 1
            fi
        fi
        sleep 20
    done
}



echo "Starting Full Deployment..."

# Sync all spark logic
aws s3 cp src/glue/jobs/silver.py s3://${ASSETS_BUCKET}/scripts/silver.py
aws s3 cp src/glue/jobs/gold.py s3://${ASSETS_BUCKET}/scripts/gold.py

# Package and sync schemas
cd src/glue/ && zip -r ../../schemas.zip schemas/ > /dev/null && cd ../../
aws s3 cp schemas.zip s3://${ASSETS_BUCKET}/libs/schemas.zip

# Trigger silver job
echo "Triggering Silver Job..."
SILVER_RUN_ID=$(aws glue start-job-run --job-name "${SILVER_JOB}" --query 'JobRunId' --output text)
wait_for_job "${SILVER_JOB}" "$SILVER_RUN_ID"

# Trigger silver crawler
echo "Triggering Silver Crawler..."
aws glue start-crawler --name "${SILVER_CRAWLER}"
wait_for_crawler "${SILVER_CRAWLER}"

# Trigger gold job
echo "Triggering Gold Job..."
GOLD_RUN_ID=$(aws glue start-job-run --job-name "${GOLD_JOB}" --query 'JobRunId' --output text)
wait_for_job "${GOLD_JOB}" "$GOLD_RUN_ID"

# Trigger gold crawler
echo "Triggering Gold Crawler..."
aws glue start-crawler --name "${GOLD_CRAWLER}"
wait_for_crawler "${GOLD_CRAWLER}"

echo "End-to-End Pipeline Finished Successfully!"
