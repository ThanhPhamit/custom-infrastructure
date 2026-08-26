resource "aws_acm_certificate" "this" {
  domain_name       = var.domain
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.domain}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.tags,
    {
      "Name" = var.domain
    }
  )
}

resource "aws_acm_certificate" "virginia" {
  domain_name       = var.domain
  validation_method = "DNS"
  provider          = aws.virginia

  subject_alternative_names = [
    "*.${var.domain}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.tags,
    {
      "Name" = var.domain
    }
  )
}

data "aws_route53_zone" "this" {
  name         = var.app_dns_zone
  private_zone = false
}

resource "aws_route53_record" "this" {
  depends_on = [aws_acm_certificate.virginia]

  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = data.aws_route53_zone.this.zone_id
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  depends_on              = [aws_route53_record.this]
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.this : record.fqdn]
  # provider = aws.virginia
}

resource "aws_acm_certificate_validation" "virginia" {
  depends_on              = [aws_route53_record.this]
  certificate_arn         = aws_acm_certificate.virginia.arn
  validation_record_fqdns = [for record in aws_route53_record.this : record.fqdn]
  provider                = aws.virginia
}

# =============================================================================
# Certificate expiry. See create_expiry_alarm for why this is not redundant with ACM auto-renewal.
# =============================================================================
resource "aws_cloudwatch_metric_alarm" "expiry" {
  count = var.create_expiry_alarm ? 1 : 0

  alarm_name          = "${replace(var.domain, ".", "-")}-acm-expiring"
  alarm_description   = "Certificate for ${var.domain} has fewer than ${var.expiry_alarm_days} days left. ACM renews on its own only while the DNS validation record still resolves -- this fires when it has not."
  namespace           = "AWS/CertificateManager"
  metric_name         = "DaysToExpiry"
  statistic           = "Minimum"
  comparison_operator = "LessThanThreshold"
  threshold           = var.expiry_alarm_days
  period              = 86400
  evaluation_periods  = 1

  # Absence would mean ACM stopped reporting on the certificate at all, which is itself worth
  # knowing -- but it also happens briefly around creation, so give it one day before believing it.
  treat_missing_data = "breaching"

  dimensions = {
    CertificateArn = aws_acm_certificate.this.arn
  }

  alarm_actions = [var.expiry_alarm_sns_topic_arn]
  ok_actions    = []

  lifecycle {
    precondition {
      condition     = var.expiry_alarm_sns_topic_arn != ""
      error_message = "create_expiry_alarm requires expiry_alarm_sns_topic_arn."
    }
  }

  tags = merge(var.tags, {
    Name      = "${replace(var.domain, ".", "-")}-acm-expiring"
    ManagedBy = "Terraform"
  })
}
