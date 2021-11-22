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
     // Region set to UK, could be elsewhere
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


resource "aws_s3_bucket_policy" "CloudTrailAccessToLogBucket" {
    bucket = "${aws_s3_bucket.LogsFromCloudTrail.id}"
    policy = jsonencode({
        "Version": "2012-10-17"
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "cloudtrail.amazonaws.com"
                },

                "Action": [
                    "s3:GetBucketAcl",
                    "s3:GetObject",
                    "s3:GetObjectAcl",
                    "s3:PutBucketAcl",
                    "s3:PutObject",
                    "s3:PutObjectAcl"
                ],
                "Resource": [
                "arn:aws:s3:::logs-from-cloudtrail-7834",
                "arn:aws:s3:::logs-from-cloudtrail-7834/*"
                ]
            }
        ]
    })
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
}

resource "aws_s3_bucket_public_access_block" "LogsFromCloudTrail-ACCESS" {
  bucket = aws_s3_bucket.LogsFromCloudTrail.id

  block_public_acls = true
  block_public_policy = false
  ignore_public_acls = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "LogAccessFromLogBucket-ACCESS" {
  bucket = aws_s3_bucket.LogAccessFromLogBucket.id

  block_public_acls = true
  block_public_policy = false
  ignore_public_acls = true
  restrict_public_buckets = true
}




// Creating Customer Managed CMKs


resource "aws_cloudtrail" "EnableAllRegionCT" {
    name = "Account-CloudTrail"
    s3_bucket_name = "${aws_s3_bucket.LogsFromCloudTrail.id}"

    // Enables log file validation
    // Found in terraform docs
    enable_log_file_validation = true

    
    // Sets logging trail to all regions rather than region specific
    is_multi_region_trail = true

    // is_organization_trail
    // command useful if organization trail is required.
    // resource must be in master account of org

    // Includes both management events and global events in CloudTrail
    include_global_service_events = true
    event_selector{
        read_write_type = "All"
        include_management_events = true
    }
    // Encrypting Logs at rest
    //kms_key_id
}