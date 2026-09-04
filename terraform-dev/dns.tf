# NOTE: this stack owns the dhinrichs.dev hosted zone for now, since the prod
# stack (mitto-infra/terraform) hasn't been applied yet. Before ever applying
# the prod stack, decide how the zone is shared/migrated — see docs/decisions.md.

resource "aws_route53_zone" "main" {
  name = var.domain
  tags = { Name = var.domain }
}

resource "aws_acm_certificate" "wildcard" {
  domain_name               = var.domain
  subject_alternative_names = ["*.${var.domain}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${local.name}-wildcard-cert" }
}

resource "aws_route53_record" "cert_validation" {
  # Keyed by resource_record_name, not domain_name — the apex and wildcard SANs
  # of this cert share the identical validation CNAME. The trailing `...`
  # groups same-key entries into a list instead of erroring on the duplicate;
  # that list always has exactly 1 element in practice.
  for_each = {
    for dvo in aws_acm_certificate.wildcard.domain_validation_options :
    dvo.resource_record_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }...
  }

  zone_id = aws_route53_zone.main.zone_id
  name    = each.value[0].name
  type    = each.value[0].type
  ttl     = 60
  records = [each.value[0].record]
}

resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.${var.domain}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "app" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "app.${var.domain}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "realtime" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "realtime.${var.domain}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
