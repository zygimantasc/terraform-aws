# Define local variables for subnet ID, security group, and lambda function name.
locals {
  subnet_id             = ["subnet-00000000"]
  security_group        = ["sg-0000000000"]
  lambda_function_name  = "test_node_hc"
}

# Create an archive file containing the Lambda function code.
data "archive_file" "lambda_hc_zip" {
  type = "zip"
  source_file  = "lambda_function.py"
  output_path = "healthcheck_function.zip"
}

# Define an AWS Lambda function resource.
resource "aws_lambda_function" "lambda" {
  function_name     = "${local.lambda_function_name}_function"
  filename          = data.archive_file.lambda_hc_zip.output_path
  source_code_hash  = data.archive_file.lambda_hc_zip.output_base64sha256
  role              = aws_iam_role.lambda_role.arn
  handler           = "lambda_function.lambda_handler"
  runtime           = "python3.7"
  timeout           = 20

  vpc_config {
    subnet_ids         = "${local.subnet_id}"
    security_group_ids = "${local.security_group}"
  }
}

# Define an AWS CloudWatch event rule to schedule the Lambda function.
resource "aws_cloudwatch_event_rule" "lambda_event" {
  name                  = "run_${local.lambda_function_name}_function"
  description           = "Schedule lambda function"
  schedule_expression   = "rate(1 minute)"
}

# Define an AWS CloudWatch event target to associate with the Lambda function.
resource "aws_cloudwatch_event_target" "lambda_function_target" {
  target_id = "${local.lambda_function_name}_function_target"
  rule      = aws_cloudwatch_event_rule.lambda_event.name
  arn       = aws_lambda_function.lambda.arn
}

# Define an AWS Lambda permission to allow execution from CloudWatch events.
resource "aws_lambda_permission" "allow_cloudwatch" {
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.lambda.function_name
    principal = "events.amazonaws.com"
    source_arn = aws_cloudwatch_event_rule.lambda_event.arn
}