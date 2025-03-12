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
  #  default = "ami-0a49b025fffbbdac6" # Ubuntu 18.04
  #  default = "ami-01c14b7c8b4d5d4fa"  # Ubuntu 18.04
  # default = "ami-00eeec150ceb5f5a8" # Ubuntu 16.04
    default = "ami-0f16019ed81305805"
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
  default = "ami-00f86d6f4ee866d49" # ubuntu 18.04
}

variable "db_instance_type" {
  default = "t4g.small"
}

variable "my_ip" {
  default     = "127.0.0.1"
}

variable "log_retention_days" {
  type        = number
  default     = 365
}