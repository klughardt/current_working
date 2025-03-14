module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.9.0"

  name                 = "workwiz"
  cidr                 = "10.16.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["10.16.1.0/24", "10.16.2.0/24", "10.16.3.0/24"]
  public_subnets       = ["10.16.4.0/24", "10.16.5.0/24", "10.16.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}



