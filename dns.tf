resource "aws_route53_zone" "magento" {
  name = "magento.kubeconfigstore.tk"

}
resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.magento.zone_id
  name    = "magento.kubeconfigstore.tk"
  type    = "A"
  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = false
  }
}
resource "tls_private_key" "key" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "self-sign" {
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.key.private_key_pem

  subject {
    common_name  = "scandiweb"
    organization = "scandiweb, Inc"
  }

  validity_period_hours = 720

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "cert" {
  domain_name = aws_route53_record.www.fqdn
#  private_key      = tls_private_key.key.private_key_pem
 # certificate_body = tls_self_signed_cert.self-sign.cert_pem
    validation_method = "DNS"

}
resource "aws_route53_record" "cert_validation" {
  allow_overwrite = true
  name            = tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_name
  records         = [tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_value]
  type            = tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_type
  zone_id         = aws_route53_zone.magento.id
  ttl             = 60
}



output "ns" { value = aws_route53_zone.magento.name_servers }
