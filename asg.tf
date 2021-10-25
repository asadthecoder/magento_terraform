provider "aws" { region = "us-east-1" }

module "VPC" {
  source = "./modules/vpc"
}

module "launch_template" {
  source = "./modules/launch_template"
  sg_id  = ["${module.VPC.http-https-sg}"]
}

resource "aws_lb" "alb" {
  name            = "magento-alb"
  subnets         = ["${module.VPC.pub-subnet-1}", "${module.VPC.pub-subnet-2}"]
  security_groups = ["${module.VPC.http-https-sg}"]
  tags = {
    Name = "terraform-elb"
  }
}


resource "aws_lb_target_group" "magento_target_group" {
  name       = "magento-target-group"
  port       = "80"
  protocol   = "HTTP"
  vpc_id     = module.VPC.vpc-id
  slow_start = 300
  tags = {
    name = "magento_target_group"
  }
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 10
    timeout             = 120
    interval            = 300
    path                = "/"
    port                = 80
    matcher             = "200-302"
  }
}

resource "aws_lb_target_group" "varnish_target_group" {
  name     = "varnish-target-group"
  port     = "80"
  protocol = "HTTP"
  vpc_id   = module.VPC.vpc-id
  tags = {
    name = "varnish_target_group"
  }
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 10
    timeout             = 120
    interval            = 300
    path                = "/"
    port                = 80
    matcher             = "200-302"
  }
}

resource "aws_lb_listener" "default_listener" {
  load_balancer_arn = aws_lb.alb.arn
  #port              = 443
  #protocol          = "HTTPS"
  #certificate_arn   = aws_acm_certificate.cert.arn
    port = 80
    protocol = "HTTP"
  default_action {
    type = "redirect"
    redirect {
        port = "443"
        protocol = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }


resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.cert.arn
#    port = 80
#    protocol = "HTTP"
  default_action {
        target_group_arn = aws_lb_target_group.varnish_target_group.arn
        type = "forward"
    }
  }

resource "aws_lb_listener_rule" "static" {
  listener_arn = aws_lb_listener.alb_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.magento_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/static/*"]
    }
  }

}

resource "aws_lb_listener_rule" "media" {
  listener_arn = aws_lb_listener.alb_listener.arn
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.magento_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/media/*"]
    }
  }

}

resource "aws_lb_listener_rule" "root" {
  listener_arn = aws_lb_listener.alb_listener.arn
  priority     = 95

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.varnish_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

}
resource "aws_lb_listener_rule" "cert" {
  listener_arn = aws_lb_listener.alb_listener.arn
  priority     = 90

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.magento_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/.well-lnown/*"]
    }
  }

}

resource "aws_autoscaling_attachment" "alb_autoscale" {
  alb_target_group_arn   = aws_lb_target_group.magento_target_group.arn
  autoscaling_group_name = aws_autoscaling_group.magento.id
}

resource "aws_autoscaling_group" "magento" {
  launch_template {
    id      = module.launch_template.template-id
    version = "$Latest"
  }
  vpc_zone_identifier = ["${module.VPC.pub-subnet-1}", "${module.VPC.pub-subnet-2}"]
  min_size            = 1
  max_size            = 1
  enabled_metrics     = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupTotalInstances"]
  metrics_granularity = "1Minute"
  target_group_arns   = ["${aws_lb_target_group.magento_target_group.arn}"]
  health_check_type   = "ELB"
  tag {
    key                 = "Name"
    value               = "magento-asg"
    propagate_at_launch = true
  }
}
resource "aws_autoscaling_attachment" "varnish_autoscale" {
  alb_target_group_arn   = aws_lb_target_group.varnish_target_group.arn
  autoscaling_group_name = aws_autoscaling_group.varnish.id
}

resource "aws_autoscaling_group" "varnish" {
  launch_template {
    id      = module.launch_template.template-id
    version = "$Latest"
  }
  vpc_zone_identifier = ["${module.VPC.pub-subnet-1}", "${module.VPC.pub-subnet-2}"]
  min_size            = 1
  max_size            = 1
  enabled_metrics     = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupTotalInstances"]
  metrics_granularity = "1Minute"
  target_group_arns   = ["${aws_lb_target_group.varnish_target_group.arn}"]
  health_check_type   = "ELB"
  tag {
    key                 = "Name"
    value               = "varnish-asg"
    propagate_at_launch = true
  }
}

output "ASG-ALB-DNS-Name" { value = aws_lb.alb.dns_name }
