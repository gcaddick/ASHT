
// Defining S3 bucket for access logs of CloudTrail logs
resource "aws_s3_bucket" "LogAccessFromLogBucket" {
    bucket = "log-access-from-log-bucket-7834"
    acl    = "log-delivery-write" 
    // force-destroy set to true for my testing
    force_destroy = true

 versioning {
    enabled = true
 }
    // Cost saving to move logs older than X days to cheaper storage
 lifecycle_rule {
    enabled = true

    transition {
        days = 30
        storage_class = "STANDARD_IA"
    }
    transition {
      days = 60
      storage_class = "GLACIER"
    }
 }
}

// Defining S3 bucket for CloudTrail logs
resource "aws_s3_bucket" "LogsFromCloudTrail" {
    bucket = "logs-from-cloudtrail-7834"
    acl    = "private" 
    // force-destroy set to true for my testing
    force_destroy = true

 versioning {
    enabled = true
 }

 // Enabling bucket access logging 
 // Bucket logging sent to different bucket
 logging{ 
    target_bucket = aws_s3_bucket.LogAccessFromLogBucket.id
    target_prefix = "log/"
 }

    // Cost saving to move logs older than X days to cheaper storage
 lifecycle_rule {
    prefix  = "log/"
    enabled = true

    transition {
        days = 30
        storage_class = "STANDARD_IA"
    }
    transition {
      days = 60
      storage_class = "GLACIER"
    }
 }
 policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::logs-from-cloudtrail-7834"
        },
        {
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::logs-from-cloudtrail-7834/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        }
    ]
}
POLICY
}

resource "aws_s3_bucket_public_access_block" "LogsFromCloudTrail-ACCESS" {
  bucket = aws_s3_bucket.LogsFromCloudTrail.id

  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "LogAccessFromLogBucket-ACCESS" {
  bucket = aws_s3_bucket.LogAccessFromLogBucket.id

  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}