variable "bronze_bucket" { type = string }
variable "silver_bucket" { type = string }
variable "gold_bucket"   { type = string }
variable "assets_bucket" { type = string }
variable "dlq_bucket"    { type = string }
variable "athena_bucket" { type = string }

variable "db_name" { type = string }

variable "aws_region"  { type = string }
variable "aws_profile" { type = string }