/*

Main terraform file for Account Security Hardening
Objective:
CloudTrail Requirements:
    1. Enable CloudTrail
        a. Ensure CloudTrail is enabled in all regions
        b. Ensure CloudTrail log file validation is enabled.
        c. Ensure that both management and global events are captured within
        CloudTrail.
        d. Ensure CloudTrail logs are encrypted at rest using KMS customer
        managed CMKs.

    2. Ensure CloudTrail logs are stored within an S3 bucket.
        a. Ensure controls are in place to block public access to the bucket.
        b. Ensure S3 bucket access logging is enabled on the CloudTrail S3 bucket.
    3. Ensure CloudTrail trails are integrated with CloudWatch Logs.

CloudWatch Filters and Alarms Requirements:
    Send an email to a configured email address when any of the following events are
    logged within CloudTrail:
        4. Unauthorized API calls
        5. Management Console sign-in without MFA
        6. Usage of the "root" account

Default VPCs Requirements:
    7. Remove the default VPC within every region of the account.


*/

// Provider is AWS
provider "aws" {
     region = "eu-west-2"
}


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