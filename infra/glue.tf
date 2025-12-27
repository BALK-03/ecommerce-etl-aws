resource "aws_glue_catalog_database" "datalake_db" { name = var.db_name }

resource "aws_glue_job" "silver_layer" {
  name = "silver_layer_job"
  role_arn = aws_iam_role.glue_role.arn
  glue_version = "4.0"
  worker_type = "G.1X"
  number_of_workers = 2
  command {
    script_location = "s3://${var.assets_bucket}/scripts/silver.py"
  }
  default_arguments = {
    "--extra-py-files" = "s3://${var.assets_bucket}/libs/schemas.zip"
    "--job-bookmark-option" = "job-bookmark-enable"
  }
}

resource "aws_glue_job" "gold_layer" {
  name = "gold_layer_job"
  role_arn = aws_iam_role.glue_role.arn
  glue_version = "4.0"
  worker_type = "G.1X"
  number_of_workers = 2
  command {
    script_location = "s3://${var.assets_bucket}/scripts/gold.py"
  }
  default_arguments = { "--job-bookmark-option" = "job-bookmark-enable" }
}

resource "aws_glue_crawler" "silver_crawler" {
  database_name = aws_glue_catalog_database.datalake_db.name
  name          = "silver_orders_crawler"
  role          = aws_iam_role.glue_role.arn
  s3_target { path = "s3://${var.silver_bucket}/orders/" }
  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = { Partitions = { AddOrUpdateBehavior = "InheritFromTable" } }
  })
}

resource "aws_glue_crawler" "gold_crawler" {
  database_name = aws_glue_catalog_database.datalake_db.name
  name          = "gold_layer_crawler"
  role          = aws_iam_role.glue_role.arn
  s3_target { path = "s3://${var.gold_bucket}/daily_revenue/" }
  s3_target { path = "s3://${var.gold_bucket}/top_products/" }
}
