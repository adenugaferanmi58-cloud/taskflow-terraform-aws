resource "aws_s3_bucket" "app" {
  bucket        = "feranmi-taskflow-app-2026" # must be globally unique, change if taken
  force_destroy = true                        # lets terraform destroy empty or fill it

  tags = {
    Name      = "taskflow-app-bucket"
    ManagedBy = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "app" {
  bucket                  = aws_s3_bucket.app.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
locals {
  app_files = [
    "app.py",
    "requirements.txt",
    "templates/index.html",
    "static/style.css",
    "static/app.js",
  ]
}
resource "aws_s3_object" "app_files" {
  for_each = toset(local.app_files)

  bucket = aws_s3_bucket.app.id
  key    = "app/${each.value}"
  source = "${path.module}/../app/${each.value}"
  etag   = filemd5("${path.module}/../app/${each.value}")
}