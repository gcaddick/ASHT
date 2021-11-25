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

data "aws_caller_identity" "current" {} // Used for identifying the current user


resource "aws_default_vpc" "default_vpc" {}

resource "aws_default_network_acl" "default_network_acl" {
    default_network_acl_id = "${aws_default_vpc.default_vpc.default_network_acl_id}"

    // No egress or ingress rules defined, therefore no traffic allowed
}

resource "aws_default_security_group" "default_sg" {
    vpc_id = "${aws_default_vpc.default_vpc.id}"
    // No egress or ingress rules defined, therefore no traffic allowed
}
resource "aws_default_route_table" "default_route" {
    default_route_table_id = "${aws_default_vpc.default_vpc.default_route_table_id}"
    route = []
}

// Creating Customer Managed CMKs
resource "aws_kms_key" "EncryptingLogsAtRest" {
    description = "Used for encrypting logs at rest in bucket"
    key_usage = "ENCRYPT_DECRYPT"
    customer_master_key_spec = "SYMMETRIC_DEFAULT"

    // Policy defines cloudtrail usage of key and user ability to edit key configs
    policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": [                  
                "kms:Encrypt",
                "kms:Decrypt",
                "kms:ReEncrypt",
                "kms:GenerateDataKey*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Principal": { 
                "AWS": "${data.aws_caller_identity.current.arn}"
            },
            "Action": [
                "kms:*"
            ],
            "Resource": "*"
        }
    ]
}
POLICY
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
// Policy allows cloudtrail access to the s3 bucket to get bucket ACL
// Policy allows cloudtrail put objects in s3 bucket
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

// Block all public access to S3 buckets
resource "aws_s3_bucket_public_access_block" "LogsFromCloudTrail-ACCESS" {
  bucket = aws_s3_bucket.LogsFromCloudTrail.id

  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

// Block all public access to S3 buckets
resource "aws_s3_bucket_public_access_block" "LogAccessFromLogBucket-ACCESS" {
  bucket = aws_s3_bucket.LogAccessFromLogBucket.id

  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

// IAM role for cloudtrail to assume
resource "aws_iam_role" "CloudWatchLogRole" {
    name = "cloudwatch-log-role"
    assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
POLICY
}

// IAM policy that allows access to logs* in specific log group
resource "aws_iam_role_policy" "CloudWatchLogRolePolicy" {
    name = "cloudwatch-log-role-policy"
    role = "${aws_iam_role.CloudWatchLogRole.id}"
    policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "logs:*",
            "Resource": "${aws_cloudwatch_log_group.CloudTrailLogGroup.arn}*"
        }
    ]
}
POLICY
}

resource "aws_cloudtrail" "EnableAllRegionCT" {
    name = "Account-CloudTrail"
    s3_bucket_name = "${aws_s3_bucket.LogsFromCloudTrail.id}"

    enable_log_file_validation = true  // Enables log file validation, Found in terraform docs

    is_multi_region_trail = true     // Sets logging trail to all regions rather than region specific
    s3_key_prefix = ""
    // is_organization_trail
    // command useful if organization trail is required.
    // resource must be in master account of org

    // Includes both management events and global events in CloudTrail
    include_global_service_events = true
    event_selector{
        read_write_type = "All"
        include_management_events = true
    }
    
    kms_key_id = aws_kms_key.EncryptingLogsAtRest.arn // Encrypting Logs at rest

    cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.CloudTrailLogGroup.arn}:*"
    cloud_watch_logs_role_arn = "${aws_iam_role.CloudWatchLogRole.arn}"
}

// Defines cloudwatch log group
resource "aws_cloudwatch_log_group" "CloudTrailLogGroup" {
    name = "cloudtrail-log-group"
}


// Define unathorized API call metric filter
resource "aws_cloudwatch_log_metric_filter" "UnAuthAPI" {
    name = "unauth-api"
    //pattern = "\"$.errorCode = AccessDenied*\""
    pattern = "{($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\")}" 

    log_group_name = "${aws_cloudwatch_log_group.CloudTrailLogGroup.id}"
    metric_transformation {
        name = "UnAuthAPICalls"
        namespace = "CloudTrailMetrics"
        value = 1
    }
}

// Define the Alarm for the API call metric filter
resource "aws_cloudwatch_metric_alarm" "AlarmForUnAthorizedAPIcall" {
    alarm_name = "alarm-for-unathorized-api-call"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = "1"
    metric_name = "UnAuthAPICalls"
    namespace = "CloudTrailMetrics"
    period = "60"
    threshold = "0"
    statistic = "SampleCount"
    alarm_actions = [aws_sns_topic.UnauthorizedAPI.arn]
}

// Create SNS topic for the unauthorised API call
resource "aws_sns_topic" "UnauthorizedAPI" {
    name = "UnauthorizedAPICall"
}

// Subscribe a temporary email to the SNS topic
resource "aws_sns_topic_subscription" "UnAuthAPIemail" {
    topic_arn = "${aws_sns_topic.UnauthorizedAPI.arn}"
    protocol = "email"
    endpoint = "ledore5458@kyrescu.com"
}

// Define metric filter for an account logging on with no MFA
resource "aws_cloudwatch_log_metric_filter" "NoMFA" {
    name = "no-mfa"
    pattern = "{($.eventName = ConsoleLogin) && ($.additionalEventData.MFAUsed = \"No\")}"

    log_group_name = "${aws_cloudwatch_log_group.CloudTrailLogGroup.id}"
    metric_transformation {
        name = "no-mfa"
        namespace = "CloudTrailMetrics"
        value = 1
    }
}

// Defining Alarm for the no MFA logon
resource "aws_cloudwatch_metric_alarm" "AlarmForNoMFA" {
    alarm_name = "alarm-for-no-mfa"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = "1"
    metric_name = "no-mfa"
    namespace = "CloudTrailMetrics"
    period = "60"
    threshold = "0"
    statistic = "SampleCount"
    alarm_actions = [aws_sns_topic.NoMFAtopic.arn]
}

// Creating SNS topic for no MFA
resource "aws_sns_topic" "NoMFAtopic" {
    name = "NoMFA-topic"
}

// Subscribe a temporary email to the SNS topic
resource "aws_sns_topic_subscription" "NoMFAemail" {
    topic_arn = "${aws_sns_topic.NoMFAtopic.arn}"
    protocol = "email"
    endpoint = "ledore5458@kyrescu.com"
}

// Define metric filter for usage of the root account
resource "aws_cloudwatch_log_metric_filter" "RootUsage" {
    name = "root-usage"
    pattern = "{($.eventName = ConsoleLogin) && ($.userIdentity.type = \"Root\")}"

    log_group_name = "${aws_cloudwatch_log_group.CloudTrailLogGroup.id}"
    metric_transformation {
        name = "root-usage"
        namespace = "CloudTrailMetrics"
        value = 1
    }
}
// Defining Alarm for the root usage
resource "aws_cloudwatch_metric_alarm" "AlarmForRootUsage" {
    alarm_name = "alarm-for-root-usage"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = "1"
    metric_name = "root-usage"
    namespace = "CloudTrailMetrics"
    period = "60"
    threshold = "0"
    statistic = "SampleCount"
    alarm_actions = [aws_sns_topic.RootUsagetopic.arn]
}

// Creating SNS topic for root usage
resource "aws_sns_topic" "RootUsagetopic" {
    name = "RootUsage-topic"
}

// Subscribe a temporary email to the SNS topic
resource "aws_sns_topic_subscription" "RootUsageEmail" {
    topic_arn = "${aws_sns_topic.RootUsagetopic.arn}"
    protocol = "email"
    endpoint = "ledore5458@kyrescu.com"
}

// Define metric filter for changes to CloudTrail
resource "aws_cloudwatch_log_metric_filter" "cloudtrailChanges" {
    name = "cloudtrail-changes"
    pattern = "{ ($.eventName = CreateTrail) || ($.eventName = UpdateTrail) || ($.eventName = DeleteTrail) || ($.eventName = StartLogging) || ($.eventName = StopLogging) }"

    log_group_name = "${aws_cloudwatch_log_group.CloudTrailLogGroup.id}"
    metric_transformation {
        name = "cloudtrail-changes"
        namespace = "CloudTrailMetrics"
        value = 1
    }
}
// Defining Alarm for changes to CloudTrail
resource "aws_cloudwatch_metric_alarm" "AlarmForcloudtrailChanges" {
    alarm_name = "alarm-for-cloudtrail-changes"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = "1"
    metric_name = "cloudtrail-changes"
    namespace = "CloudTrailMetrics"
    period = "60"
    threshold = "0"
    statistic = "SampleCount"
    alarm_actions = [aws_sns_topic.cloudtrailChangestopic.arn]
}

// Creating SNS topic for changes to CloudTrail
resource "aws_sns_topic" "cloudtrailChangestopic" {
    name = "cloudtrailChanges-topic"
}

// Subscribe a temporary email to the SNS topic
resource "aws_sns_topic_subscription" "cloudtrailChangesEmail" {
    topic_arn = "${aws_sns_topic.cloudtrailChangestopic.arn}"
    protocol = "email"
    endpoint = "ledore5458@kyrescu.com"
}