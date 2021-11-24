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