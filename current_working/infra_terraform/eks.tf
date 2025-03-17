module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.30.3"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"
  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id

  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  eks_managed_node_groups = {
    workwiz_app = {
      desired_capacity = 1
      max_capacity     = 3
      min_capacity     = 1
      instance_type    = "t3.medium"
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

# Outbound connectivity to private CIDR
resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  security_group_id = module.eks.node_security_group_id # <-- Correct reference

  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["10.32.4.0/24"]
  
  lifecycle {
    ignore_changes = [cidr_blocks]
  }
}

resource "kubernetes_service_account" "web_app_sa" {
  metadata {
    name      = "web-app-sa"
    namespace = "tasky"  # Hardcoded instead of referencing a Terraform resource
  }
}
# Creating ClusterRoleBinding for cluster-admin permissions
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
    namespace = "tasky"
  }
}

# IAM Policy and Role attachment for the worker nodes
resource "aws_iam_policy" "worker_policy" {
  name        = "worker-policy"
  description = "Worker policy for the ALB Ingress"
  policy      = file("iam-policy.json")
}

resource "aws_iam_role_policy_attachment" "additional" {
  for_each = module.eks.eks_managed_node_groups
  policy_arn = aws_iam_policy.worker_policy.arn
  role       = each.value.iam_role_name
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
    value = var.cluster_name  # Use the correct variable
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

# CloudWatch observability addon
resource "aws_eks_addon" "cloudwatch_observability" {
  addon_name   = "amazon-cloudwatch-observability"
  cluster_name = module.eks.cluster_id

  lifecycle {
    ignore_changes = [addon_name]  # Prevent Terraform from trying to re-create the addon
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