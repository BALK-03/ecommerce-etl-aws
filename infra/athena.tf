resource "aws_athena_workgroup" "main" {
  name = "primary_workgroup"
  configuration {
    enforce_workgroup_configuration = true
    result_configuration {
      output_location = "s3://${var.athena_bucket}/"
      encryption_configuration { encryption_option = "SSE_S3" }
    }
    bytes_scanned_cutoff_per_query = 268435456 # 256MB
  }
  state = "ENABLED"
}
