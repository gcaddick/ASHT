
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


resource "aws_sns_topic" "UnauthorizedAPI" {
    name = "UnauthorizedAPICall"
}

resource "aws_sns_topic_subscription" "UnAuthAPIemail" {
    topic_arn = "${aws_sns_topic.UnauthorizedAPI.arn}"
    protocol = "email"
    endpoint = "ledore5458@kyrescu.com"
}