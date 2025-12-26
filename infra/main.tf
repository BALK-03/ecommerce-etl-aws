provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

# Storage (S3 BUCKETS)
resource "aws_s3_bucket" "bronze" { bucket = "badr-datalake-bronze-us-east-1" }
resource "aws_s3_bucket" "silver" { bucket = "badr-datalake-silver-us-east-1" }
resource "aws_s3_bucket" "gold" { bucket = "badr-datalake-gold-us-east-1" }
resource "aws_s3_bucket" "assets" { bucket = "badr-glue-assets-us-east-1" }
resource "aws_s3_bucket" "dlq"    { bucket = "badr-datalake-dlq-us-east-1" }
resource "aws_s3_bucket" "athena_results" { bucket = "badr-athena-results-us-east-1" }


# Metadata (GLUE CATALOG)
resource "aws_glue_catalog_database" "datalake_db" {
  name = "badr_datalake"
}
# Crawler
resource "aws_glue_crawler" "silver_crawler" {
  database_name = aws_glue_catalog_database.datalake_db.name
  name          = "silver_orders_crawler"
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.silver.bucket}/orders/"
  }

  # This ensures the crawler handles your partitions (region, year, month) correctly
  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
    }
  })
}

resource "aws_glue_crawler" "gold_crawler" {
  database_name = aws_glue_catalog_database.datalake_db.name
  name          = "gold_layer_crawler"
  role          = aws_iam_role.glue_role.arn

  s3_target { path = "s3://${aws_s3_bucket.gold.bucket}/daily_revenue/" }
  s3_target { path = "s3://${aws_s3_bucket.gold.bucket}/top_products/" }
}

# Security (IAM ROLE)
resource "aws_iam_role" "glue_role" {
  name = "glue-s3-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
    }]
  })
}

# Basic power user policy
resource "aws_iam_role_policy_attachment" "glue_s3" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Compute (GLUE JOB)
resource "aws_glue_job" "silver_layer" {
  name              = "silver_layer_job"
  role_arn          = aws_iam_role.glue_role.arn
  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2

  command {
    script_location = "s3://${aws_s3_bucket.assets.bucket}/scripts/silver.py"
    python_version  = "3"
  }

  default_arguments = {
    "--enable-continuous-cloudwatch-log" = "true"
    "--extra-py-files"                   = "s3://${aws_s3_bucket.assets.bucket}/libs/schemas.zip"
    "--job-bookmark-option"              = "job-bookmark-enable"
  }
}

resource "aws_glue_job" "gold_layer" {
  name              = "gold_layer_job"
  role_arn          = aws_iam_role.glue_role.arn
  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2

  command {
    script_location = "s3://${aws_s3_bucket.assets.bucket}/scripts/gold.py"
    python_version  = "3"
  }

  default_arguments = {
    "--enable-continuous-cloudwatch-log" = "true"
    "--job-bookmark-option"              = "job-bookmark-enable"
  }
}

# Automatic cleanup after 7 days to save money
resource "aws_s3_bucket_lifecycle_configuration" "athena_cleanup" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    id     = "cleanup-results"
    status = "Enabled"
    expiration {
      days = 7
    }
  }
}

# Create the Athena Workgroup
resource "aws_athena_workgroup" "main" {
  name = "primary_workgroup"

  configuration {
    # Users cannot change the S3 bucket or encryption settings in the UI
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }

    # COST CONTROL: Kill any query that scans more than 256MB, It's a side project
    bytes_scanned_cutoff_per_query = 268435456
  }

  description = "Workgroup for Badr Datalake - Enforces S3 results and cost limits"
  state       = "ENABLED"
}

resource "aws_s3_bucket_policy" "quicksight_access" {
  bucket = "badr-datalake-gold-us-east-1"

  policy = jsonencode({
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowQuick",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::720424066451:role/service-role/aws-quicksight-service-role-v0"
      },
      "Action": [
        "s3:GetObject",
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:GetObjectVersion",
        "s3:ListBucketVersions"
      ],
      "Resource": [
        "arn:aws:s3:::badr-datalake-gold-us-east-1",
        "arn:aws:s3:::badr-datalake-gold-us-east-1/*"
      ]
    }
  ]
})
}
