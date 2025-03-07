resource "aws_s3_bucket" "log_bucket" {
  bucket = "${var.project_name}-logs"
  force_destroy = true
}

resource "aws_s3_bucket_logging" "backup" {
  bucket = aws_s3_bucket.backup.id

  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "log/"
}

resource "aws_s3_bucket" "backup" {
  bucket = "${var.project_name}-backup-bucket"
  force_destroy = true
}

# publically accessible
resource "aws_s3_bucket_public_access_block" "backup" {
  bucket = aws_s3_bucket.backup.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
