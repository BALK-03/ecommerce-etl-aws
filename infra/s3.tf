resource "aws_s3_bucket" "bronze"         { bucket = var.bronze_bucket }
resource "aws_s3_bucket" "silver"         { bucket = var.silver_bucket }
resource "aws_s3_bucket" "gold"           { bucket = var.gold_bucket }
resource "aws_s3_bucket" "assets"         { bucket = var.assets_bucket }
resource "aws_s3_bucket" "dlq"            { bucket = var.dlq_bucket }
resource "aws_s3_bucket" "athena_results" { bucket = var.athena_bucket }

resource "aws_s3_bucket_lifecycle_configuration" "athena_cleanup" {
  bucket = aws_s3_bucket.athena_results.id
  rule {
    id     = "cleanup-results"
    status = "Enabled"
    expiration { days = 7 }
  }
}
