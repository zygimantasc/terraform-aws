resource "aws_cloudwatch_metric_alarm" "first_node_cw_alert" {
  alarm_name          = "test_node_1_lambda_hc_alert"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "test_node_1_availability"
  namespace           = "LambdaCustomHC"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "1"
  alarm_description   = "This metric monitors service availability"
}

resource "aws_cloudwatch_metric_alarm" "second_node_cw_alert" {
  alarm_name          = "test_node_2_lambda_hc_alert"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "test_node_2_availability"
  namespace           = "LambdaCustomHC"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "1"
  alarm_description   = "This metric monitors service availability"
}

resource "aws_cloudwatch_metric_alarm" "third_node_cw_alert" {
  alarm_name          = "test_node_3_lambda_hc_alert"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "test_node_3_availability"
  namespace           = "LambdaCustomHC"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "1"
  alarm_description   = "This metric monitors service availability"
}