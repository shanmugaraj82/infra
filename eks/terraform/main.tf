######################
# VPC
######################
data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  public_subnets  = [for i in range(0, 3) : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnets = [for i in range(3, 6) : cidrsubnet(var.vpc_cidr, 4, i)]

  enable_nat_gateway = true
  single_nat_gateway = true

  # Required for EKS + AWS Load Balancer Controller to pick subnets
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

######################
# EKS Cluster
######################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.10.1" # latest module version as of Nov 2025 :contentReference[oaicite:5]{index=5}

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa = true

  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    default = {
      min_size     = 2
      max_size     = 4
      desired_size = 2

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
    }
  }
}

######################
# IAM for AWS Load Balancer Controller (IRSA)
######################
# Trust policy for EKS OIDC -> IAM Role
data "aws_iam_policy_document" "alb_controller_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    # Only allow the specific SA: kube-system/aws-load-balancer-controller
    condition {
      test     = "StringEquals"
      variable = "${trimprefix(module.eks.oidc_provider_arn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

# Simple but broad IAM policy for ALB controller (lab / demo)
data "aws_iam_policy_document" "alb_controller_policy" {
  statement {
    sid     = "AllowElbAndRelated"
    effect  = "Allow"
    actions = [
      "elasticloadbalancing:*",
      "ec2:Describe*",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "iam:CreateServiceLinkedRole",
      "cognito-idp:DescribeUserPoolClient",
      "waf-regional:*",
      "wafv2:*",
      "shield:*"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "alb_controller" {
  name        = "${var.cluster_name}-alb-controller"
  description = "IAM policy for AWS Load Balancer Controller for cluster ${var.cluster_name}"
  policy      = data.aws_iam_policy_document.alb_controller_policy.json
}

resource "aws_iam_role" "alb_controller" {
  name               = "${var.cluster_name}-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_assume.json
}

resource "aws_iam_role_policy_attachment" "alb_controller_attach" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

######################
# K8s ServiceAccount for ALB Controller (IRSA)
######################
resource "kubernetes_service_account" "alb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller.arn
    }
  }

  automount_service_account_token = true
}

######################
# AWS Load Balancer Controller via Helm
######################
resource "helm_release" "aws_load_balancer_controller" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  namespace        = "kube-system"
  create_namespace = false

  values = [
    yamlencode({
      clusterName = module.eks.cluster_name
      region      = var.region
      vpcId       = module.vpc.vpc_id
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.alb_controller.metadata[0].name
      }
    })
  ]

  depends_on = [
    module.eks,
    kubernetes_service_account.alb_controller,
  ]
}

######################
# Demo Application (Deployment + Service + Ingress)
######################
resource "kubernetes_namespace" "app" {
  metadata {
    name = "demo-app"
  }
}

resource "kubernetes_deployment_v1" "demo" {
  metadata {
    name      = "demo-app"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app = "demo-app"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "demo-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "demo-app"
        }
      }

      spec {
        container {
          name  = "demo-app"
          image = "nginxdemos/hello" # simple HTTP test page
          port {
            container_port = 80
          }
        }
      }
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_service_v1" "demo" {
  metadata {
    name      = "demo-service"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app = "demo-app"
    }
  }

  spec {
    selector = {
      app = "demo-app"
    }
    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
    type = "NodePort"
  }
}

# Ingress that triggers creation of an internet-facing ALB
resource "kubernetes_ingress_v1" "app_ingress" {
  metadata {
    name      = "demo-app-ingress"
    namespace = kubernetes_namespace.app.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                  = "alb"
      "alb.ingress.kubernetes.io/scheme"            = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"       = "ip"
      "alb.ingress.kubernetes.io/listen-ports"      = "[{\"HTTP\":80}]"
      "alb.ingress.kubernetes.io/load-balancer-attributes" = "idle_timeout.timeout_seconds=60"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.demo.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.aws_load_balancer_controller]
}
