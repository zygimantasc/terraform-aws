# Define a trust policy document that allows Lambda to assume this role.
# This policy will be assigned to the lambda_role resource.
data "aws_iam_policy_document" "lambda_assume_role_policy"{
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Create an IAM role for Lambda and attach the trust policy to it.
resource "aws_iam_role" "lambda_role" {  
  name = "lambda_custom_hc_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

# Define an IAM policy that allows Lambda to send metrics to CloudWatch.
resource "aws_iam_policy" "iam_policy_for_lambda" {
  name        = "lambda_cloudwatch_putmetric_policy"
  description = "Cloudwatch policy to allow Lambda to put Metric data"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:PutMetricData"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*",
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateNetworkInterface",
                "ec2:DeleteNetworkInterface",
                "ec2:DescribeNetworkInterfaces"
            ],
            "Resource": "*"
        }
    ]
  })
}

# Attach the IAM policy to the Lambda role.
resource "aws_iam_role_policy_attachment" "attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.iam_policy_for_lambda.arn
}