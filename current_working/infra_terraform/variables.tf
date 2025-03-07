variable "project_name" {
  default = "workwiz"
}

variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "secondary_region" {
  type        = string
  default     = "us-west-1"
}

variable "vpc_cidr" {
  default = "172.16.0.0/16"
}

variable "cluster_name" {
  default = "wiz-exercise-cluster"
}

variable "mongodb_ami" {
  default = "ami-0a49b025fffbbdac6" # Ubuntu 18.04
}

variable "ec2_key_name" {
  default = "wiz-ssh-key"
}

variable "db_username" {
  default = "mongoadmin"
}

variable "db_password" {
  default = "doNotHardCodePasswordsInPlainText"
}

variable "db_ami" {
  default = "ami-0866a3c8686eaeeba"
}

variable "db_instance_type" {
  default = "t2.micro"
}

variable "my_ip" {
  default     = "127.0.0.1"
}

variable "log_retention_days" {
  type        = number
  default     = 365
}