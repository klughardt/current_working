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

output "mongodb_nlb_dns" {
  value = aws_lb.mongodb_nlb.dns_name
}

