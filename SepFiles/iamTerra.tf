
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