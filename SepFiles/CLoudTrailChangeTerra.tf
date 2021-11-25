
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