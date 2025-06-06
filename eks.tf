locals {
  cluster_name                 = "${var.cluster_name}-${replace(var.cluster_version, ".", "-")}"
  cluster_mgmt_node_group_name = "${local.cluster_name}-ng"
}

data "aws_subnets" "private" {
  depends_on = [module.vpc]
  filter {
    name   = "vpc-id"
    values = [module.vpc.vpc_id]
  }

  tags = {
    "role" = "private"
  }
}


module "eks" {
  source = "terraform-aws-modules/eks/aws"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  depends_on = [module.vpc]

  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = data.aws_subnets.private.ids

  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    "${local.cluster_mgmt_node_group_name}" = {
      instance_types = ["m7i.large"]

      labels = {
        "mgmt-node-group" = "true"
      }

      launch_template_tags = {
        Name           = "nodegroup/${local.cluster_name}"
        "cluster-name" = "${local.cluster_name}"
      }
      iam_role_name = "${local.cluster_name}-ng"
      iam_role_tags = {
        "cluster-name" = "${local.cluster_name}"
      }

      min_size     = 2
      max_size     = 10
      desired_size = 2

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 20
            volume_type = "gp3"
          }
        }
      }
    }
  }

  # EKS Addons
  cluster_addons = {
    vpc-cni = {
      before_compute = true
      most_recent    = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    coredns = {
      most_recent = true
      timeouts = {
        create = "25m"
        delete = "10m"
      }
    }
    kube-proxy             = {}
    eks-pod-identity-agent = {}
  }
}

module "eks_blueprints_addons" {
  source     = "aws-ia/eks-blueprints-addons/aws"
  version    = "~> 1.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  create_kubernetes_resources = true

  # EKS Blueprints Addons
  enable_aws_load_balancer_controller = true
}
