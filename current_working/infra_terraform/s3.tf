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

# really really publically accessible
resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.backup.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.backup.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.backup]
}

resource "aws_s3_bucket" "backup_replication" {
  provider = aws.secondary_region
  bucket   = "${var.project_name}-backup-bucket-replication"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "backup" {
  bucket = aws_s3_bucket.backup.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "backup_replication" {
  provider = aws.secondary_region
  bucket = aws_s3_bucket.backup_replication.id
  versioning_configuration {
    status = "Enabled"
  }
}


