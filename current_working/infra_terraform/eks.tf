module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.30.3"

  cluster_name    = local.cluster_name
  cluster_version = "1.30"
  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id

  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  eks_managed_node_groups = {
    workwiz_app = {
      desired_capacity = 3
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

# Namespace
resource "kubernetes_namespace" "tasky" {
  metadata {
    name = "tasky"
  }
}

# Service Account
resource "kubernetes_service_account" "web_app_sa" {
  metadata {
    name      = "web-app-sa"
    namespace = kubernetes_namespace.tasky.metadata[0].name
  }
}

# Cluster Role Binding
resource "kubernetes_cluster_role_binding" "web_app_cluster_admin" {
  metadata {
    name = "web-app-cluster-admin-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.web_app_sa.metadata[0].name
    namespace = kubernetes_namespace.tasky.metadata[0].name
  }
}

# IAM Policy for Worker Nodes
resource "aws_iam_policy" "worker_policy" {
  name        = "worker-policy"
  description = "Worker policy for the ALB Ingress"
  policy      = file("iam-policy.json")
}

# Attach IAM Policy to Worker Node Roles
resource "aws_iam_role_policy_attachment" "worker_node_attachment" {
  for_each  = module.eks.node_groups
  policy_arn = aws_iam_policy.worker_policy.arn
  role       = each.value.iam_role_name
}

# AWS Load Balancer Controller via Helm
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
    value = local.cluster_name
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

# CloudWatch Observability Addon
resource "aws_eks_addon" "cloudwatch_observability_workwiz" {
  addon_name   = "amazon-cloudwatch-observability"
  cluster_name = local.cluster_name

  lifecycle {
    ignore_changes = [addon_name]
  }

  depends_on = [module.eks]
}

# Allow outbound traffic for EKS Nodes (Security Group Rule)
resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  security_group_id = module.eks.node_security_group_id
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
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
