data "aws_vpc" "default" {
  default = true
}

# Lấy public subnet ở 2 AZ
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "map-public-ip-on-launch"
    values = [true]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Security Group
resource "aws_security_group" "ec2-server-sg" {
  name        = "ec2-server-sg"
  description = "Security group for server"
  vpc_id = data.aws_vpc.default.id

  ingress {
    description = "Allow web access"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  ingress {
    description = "Allow SSH access" 
    from_port   = 22
    to_port     = 22
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

resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Security group for ALB"
  vpc_id = data.aws_vpc.default.id

  ingress {
    description = "Allow HTTPS access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = [aws_security_group.ec2-server-sg.id]
  } 
}

# Yeu cau cert tu ACM truoc
resource "aws_acm_certificate" "ec2-server-cert" {
  domain_name       = "*.huanops.com"
  subject_alternative_names = ["huanops.com"]
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "ec2-server-cert"
  }
  
}

data "aws_route53_zone" "domain" {
  name         = "huanops.com"
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.ec2-server-cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.domain.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}
# Đảm bảo validate cert trước khi tạo resource khác
resource "aws_acm_certificate_validation" "server_cert_validation" {
  certificate_arn         = aws_acm_certificate.ec2-server-cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]  

  timeouts {
    create = "10m"
  }
}

resource "aws_alb" "ec2-server-alb" {
  name               = "ec2-server-alb"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.public.ids
  load_balancer_type = "application"
  enable_deletion_protection = false

  tags = {
    Name = "ec2-server-alb"
  }
  
}

resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.ec2-server-alb.arn
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

  for_each = var.server_definitions
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
}

resource "aws_lb_target_group" "server_tg" {
  for_each = var.server_definitions
  name     = "tg-${each.key}"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }

  tags = {
    Name = "tg-${each.key}"
  }
}

resource "aws_lb_target_group_attachment" "server_attach" {
  for_each = aws_instance.server
  target_group_arn = aws_lb_target_group.server_tg[each.key].arn
  target_id        = each.value.id
  port             = 8080
}

resource "aws_route53_record" "server_subdomain" {
  for_each = var.server_definitions
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = "${each.key}.huanops.com" 
  type    = "A"
  alias {
    name                   = aws_alb.ec2-server-alb.dns_name
    zone_id                = aws_alb.ec2-server-alb.zone_id
    evaluate_target_health = true
  }
}