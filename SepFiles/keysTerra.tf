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