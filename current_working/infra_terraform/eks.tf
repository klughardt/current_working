module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.30.3"

  cluster_name    = local.cluster_name
  cluster_version = "1.30"
  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id

  eks_managed_node_groups = {
    workwiz_app = {
      desired_capacity = 1
      max_capacity     = 3
      min_capacity     = 1
      instance_type    = "t3.small"
    }
  }

  node_security_group_additional_rules = {
    ingress_allow_access_from_control_plane = {
      type                          = "ingress"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      source_cluster_security_group = true
      description                   = "Allow access from control plane to webhook port of AWS load balancer controller"
    }
  }
}

# Define namespace in Terraform
resource "kubernetes_namespace" "tasky" {
  metadata {
    name = "tasky"
  }
}

# Security group for web application pods
resource "aws_security_group" "webapp_sg" {
  name        = "${var.project_name}-webapp-sg"
  description = "Security group for web application pods"
  vpc_id      = module.vpc.vpc_id
}

# Security group rule: Allow webapp_sg to connect to MongoDB
resource "aws_security_group_rule" "webapp_egress_mongodb" {
  type                     = "egress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  security_group_id        = aws_security_group.webapp_sg.id
  destination_security_group_id = aws_security_group.mongodb.id
}

# Attach security group to service account
resource "kubernetes_service_account" "web_app_sa" {
  metadata {
    name      = "web-app-sa"
    namespace = kubernetes_namespace.tasky.metadata[0].name
    annotations = {
      "eks.amazonaws.com/security-group" = aws_security_group.webapp_sg.id
    }
  }
}

# Helm release for AWS Load Balancer Controller
resource "helm_release" "ingress" {
  name       = "ingress"
  chart      = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  version    = "1.4.6"
  namespace  = "kube-system"

  set {
    name  = "autoDiscoverAwsRegion"
    value = "true"
  }
  set {
    name  = "autoDiscoverAwsVpcID"
    value = "true"
  }
  set {
    name  = "clusterName"
    value = module.eks.cluster_id
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  depends_on = [module.eks]
}

# Terraform Outputs
output "cluster_id" {
  value = module.eks.cluster_id
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "node_security_group_id" {
  value = module.eks.node_security_group_id
}
