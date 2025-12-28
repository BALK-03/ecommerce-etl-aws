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

resource "aws_iam_role_policy_attachment" "glue_s3" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}
# 
resource "aws_iam_role_policy" "glue_s3_access" {
  name = "glue-s3-bucket-access"
  role = aws_iam_role.glue_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:*"]
      Resource = [
        "arn:aws:s3:::${var.bronze_bucket}",
        "arn:aws:s3:::${var.bronze_bucket}/*",
        "arn:aws:s3:::${var.silver_bucket}",
        "arn:aws:s3:::${var.silver_bucket}/*",
        "arn:aws:s3:::${var.gold_bucket}",
        "arn:aws:s3:::${var.gold_bucket}/*",
        "arn:aws:s3:::${var.assets_bucket}",
        "arn:aws:s3:::${var.assets_bucket}/*"
      ]
    }]
  })
}

resource "aws_iam_role" "ec2_producer_role" {
  name = "ec2-producer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "ec2_s3_write" {
  name = "ec2-s3-write-policy"
  role = aws_iam_role.ec2_producer_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:ListBucket"]
      Resource = [
        "arn:aws:s3:::${var.bronze_bucket}",
        "arn:aws:s3:::${var.bronze_bucket}/*"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-producer-profile"
  role = aws_iam_role.ec2_producer_role.name
}
