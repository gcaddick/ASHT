
// Defines cloudwatch log group
resource "aws_cloudwatch_log_group" "CloudTrailLogGroup" {
    name = "cloudtrail-log-group"
}