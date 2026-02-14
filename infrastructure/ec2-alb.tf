resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main-vpc.id

  ingress {
    description = "Allow HTTPS access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow HTTPS access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Yeu cau cert tu ACM truoc
resource "aws_acm_certificate" "ec2-server-cert" {
  domain_name               = "huanops.com"
  subject_alternative_names = ["*.huanops.com"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "ec2-server-cert"
  }

}

data "aws_route53_zone" "domain" {
  name = "huanops.com"
}

resource "aws_route53_record" "cert_validation" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = tolist(aws_acm_certificate.ec2-server-cert.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.ec2-server-cert.domain_validation_options)[0].resource_record_type
  ttl     = 60
  records = [tolist(aws_acm_certificate.ec2-server-cert.domain_validation_options)[0].resource_record_value]
}
# Đảm bảo validate cert trước khi tạo resource khác
resource "aws_acm_certificate_validation" "server_cert_validation" {
  certificate_arn         = aws_acm_certificate.ec2-server-cert.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]

  timeouts {
    create = "10m"
  }
}

resource "aws_alb" "ec2-server-alb" {
  name                       = "ec2-server-alb"
  internal                   = false
  security_groups            = [aws_security_group.alb.id]
  subnets                    = [aws_subnet.public-subnet-1a.id, aws_subnet.public-subnet-1b.id]
  load_balancer_type         = "application"
  enable_deletion_protection = false

  tags = {
    Name = "ec2-server-alb"
  }

}

# HTTP listener chuyen huong sang HTTPS
resource "aws_lb_listener" "http_redirect_listener" {
  load_balancer_arn = aws_alb.ec2-server-alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301" # 301 Moved Permanently
    }
  }
}
resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_alb.ec2-server-alb.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate_validation.server_cert_validation.certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      status_code  = "404"
      content_type = "text/plain"
      message_body = "Service Not Found or Routing Rule Missing."
    }
  }
}
resource "aws_lb_listener_rule" "server_rule" {
  for_each     = var.server_definitions
  listener_arn = aws_lb_listener.https_listener.arn
  priority     = index(keys(var.server_definitions), each.key) + 10 # Priority must be unique and between 1-50000

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.server_tg[each.key].arn
  }

  condition {
    host_header {
      values = ["${each.key}.huanops.com"]
    }
  }
  condition {
    path_pattern {
      values = ["/*"] # Khớp với mọi thứ (bao gồm /, /login, /manage, ...)
    }
  }
}

resource "aws_lb_target_group" "server_tg" {
  for_each = var.server_definitions
  name     = "tg-${each.key}"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main-vpc.id
  health_check {
    path                = var.server_definitions[each.key].health_check_path
    interval            = 30
    timeout             = 20
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }

  tags = {
    Name = "tg-${each.key}"
  }
}

resource "aws_lb_target_group_attachment" "server_attach" {
  for_each         = aws_instance.server
  target_group_arn = aws_lb_target_group.server_tg[each.key].arn
  target_id        = each.value.id
  port             = 8080
}

resource "aws_route53_record" "server_subdomain" {
  for_each = var.server_definitions
  zone_id  = data.aws_route53_zone.domain.zone_id
  name     = "${each.key}.huanops.com"
  type     = "A"
  alias {
    name                   = aws_alb.ec2-server-alb.dns_name
    zone_id                = aws_alb.ec2-server-alb.zone_id
    evaluate_target_health = true
  }
}

