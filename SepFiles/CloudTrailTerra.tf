
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
