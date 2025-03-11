resource "aws_security_group" "nlb" {
  name        = "${var.project_name}-nlb-sg"
  description = "Security group for MongoDB NLB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]  # Allow traffic from private subnet
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "mongodb_tg" {
  name        = "${var.project_name}-mongodb-tg"
  port        = 27017
  protocol    = "TCP"  # Use TCP, since MongoDB isn't HTTP-based
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"

  health_check {
    interval            = 30
    protocol            = "TCP"  # Check if port is open
    port                = "27017"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "mongodb_attachment" {
  target_group_arn = aws_lb_target_group.mongodb_tg.arn
  target_id        = aws_instance.mongodb.id
  protocol         = "TCP"
  port            = 27017
}

resource "aws_lb_listener" "mongodb_listener" {
  load_balancer_arn = aws_lb.mongodb_nlb.arn
  protocol          = "TCP"
  port             = 27017  # MongoDB port

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mongodb_tg.arn
  }
}

output "mongodb_nlb_dns" {
  value = aws_lb.mongodb_nlb.dns_name
}

resource "aws_lb" "mongodb_nlb" {
  name               = "${var.project_name}-mongodb-nlb"
  internal           = false  # Change to true if you want an internal NLB
  load_balancer_type = "network"
  security_groups    = [aws_security_group.nlb.id]  # Attach NLB SG
  subnets           = module.vpc.public_subnets  # Place in public subnets
}
