
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


resource "aws_sns_topic" "RootUsagetopic" {
    name = "RootUsage-topic"
}

resource "aws_sns_topic_subscription" "RootUsageEmail" {
    topic_arn = "${aws_sns_topic.RootUsagetopic.arn}"
    protocol = "email"
    endpoint = "ledore5458@kyrescu.com"
}