# Define local variables for configuration settings.
locals {
  ttl                    = 60
  zone_name              = "nodes.local"
  first_node_ip          = "10.0.0.1"
  second_node_ip         = "10.0.0.2"
  third_node_ip          = "10.0.0.3"
  region                 = "eu-central-1"
  main_target_domain     = "web"
  failover_target_domain = "web-failover"
  vpc_id                 = "vpc-00000000"
}

# Create Route 53 health checks for the first, second, and third nodes.
resource "aws_route53_health_check" "first_route53_hc" {
  type                            = "CLOUDWATCH_METRIC"
  cloudwatch_alarm_name           = aws_cloudwatch_metric_alarm.first_node_cw_alert.alarm_name
  cloudwatch_alarm_region         = "${local.region}"
  insufficient_data_health_status = "LastKnownStatus"

  tags = {
    Name = "test_node_1_dns_hc"
  }
}

resource "aws_route53_health_check" "second_route53_hc" {
  type                            = "CLOUDWATCH_METRIC"
  cloudwatch_alarm_name           = aws_cloudwatch_metric_alarm.second_node_cw_alert.alarm_name
  cloudwatch_alarm_region         = "${local.region}"
  insufficient_data_health_status = "LastKnownStatus"

  tags = {
    Name = "test_node_2_dns_hc"
  }  
}

resource "aws_route53_health_check" "third_route53_hc" {
  type                            = "CLOUDWATCH_METRIC"
  cloudwatch_alarm_name           = aws_cloudwatch_metric_alarm.third_node_cw_alert.alarm_name
  cloudwatch_alarm_region         = "${local.region}"
  insufficient_data_health_status = "LastKnownStatus"

  tags = {
    Name = "test_node_3_dns_hc"
  }
}

# Create a private Route 53 zone associated with the specified VPC.
resource "aws_route53_zone" "private" {
  name = "${local.zone_name}"

  vpc {
    vpc_id = "${local.vpc_id}"
  }
}

# Create Route 53 records for main (primary and secondary) and failover (primary and secondary) targets.
resource "aws_route53_record" "main_primary" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "${local.main_target_domain}"
  type    = "A"
  ttl     = "${local.ttl}"

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier = "primary"
  records        = ["${local.first_node_ip}"]
  health_check_id = aws_route53_health_check.first_route53_hc.id
}

resource "aws_route53_record" "main_secondary" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "${local.main_target_domain}"
  type    = "A"

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "secondary"

  alias {
    name                   = "${aws_route53_record.failover_primary.name}.${local.zone_name}"
    zone_id                = aws_route53_zone.private.zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "failover_primary" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "${local.failover_target_domain}"
  type    = "A"
  ttl     = "${local.ttl}"

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier = "primary"
  records        = ["${local.second_node_ip}"]
  health_check_id = aws_route53_health_check.second_route53_hc.id
}

resource "aws_route53_record" "failover_secondary" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "${local.failover_target_domain}"
  type    = "A"
  ttl     = "${local.ttl}"

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "secondary"
  records        = ["${local.third_node_ip}"]
  health_check_id = aws_route53_health_check.third_route53_hc.id
}