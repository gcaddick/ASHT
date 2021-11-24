
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

