resource "aws_lb" "mongodb_nlb" {
  name               = "${var.project_name}-mongodb-nlb"
  internal           = false  # This makes it public
  load_balancer_type = "network"
  security_groups    = [aws_security_group.nlb.id]
  subnets           = module.vpc.public_subnets

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-mongodb-nlb"
  }
}

resource "aws_lb_target_group" "mongodb_tg" {
  name     = "${var.project_name}-mongodb-tg"
  port     = 27017
  protocol = "TCP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    protocol            = "TCP"
    port                = 27017
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
  }
}

resource "aws_lb_target_group_attachment" "mongodb" {
  target_group_arn = aws_lb_target_group.mongodb_tg.arn
  target_id        = aws_instance.mongodb.id
  port            = 27017
}

resource "aws_lb_listener" "mongodb_listener" {
  load_balancer_arn = aws_lb.mongodb_nlb.arn
  protocol          = "TCP"
  port             = 27017

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mongodb_tg.arn
  }
}

output "mongodb_nlb_dns_name" {
  description = "DNS name of the MongoDB NLB"
  value       = aws_lb.mongodb_nlb.dns_name
}