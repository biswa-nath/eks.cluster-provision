module "eks" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-eks.git?ref=2cb1fac31b0fc2dd6a236b0c0678df75819c5a3b"

  cluster_name                   = var.cluster_name
  cluster_version                = var.kubernetes_version
  cluster_endpoint_public_access = true

  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnet_ids

  # Enable OIDC provider for the cluster
  enable_irsa = true

  # Add IAM users/roles to the aws-auth configmap
  manage_aws_auth_configmap = true
  aws_auth_roles = [
    {
      rolearn  = aws_iam_role.karpenter_node.arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers", "system:nodes"]
    }
  ]

  # EKS Managed Node Group
  eks_managed_node_groups = {
    initial = {
      name            = "${var.cluster_name}-ng"
      use_name_prefix = false

      subnet_ids = local.private_subnet_ids

      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_size

      instance_types = var.node_group_instance_types
      capacity_type  = "ON_DEMAND"
      ami_type       = "AL2023_ARM_64_STANDARD"
      disk_size      = var.node_group_disk_size

      tags = merge(
        local.tags,
        {
          "karpenter.sh/discovery" = var.cluster_name
        }
      )
    }
  }

  # EKS Addons
  cluster_addons = {
    vpc-cni = {
      most_recent = true
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
    }
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    metrics-server = {
      most_recent = true
    }
    #aws-ebs-csi-driver = {
    #  most_recent = true
    #  service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    #}
    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  tags = local.tags
}

# IAM role for EBS CSI driver
module "ebs_csi_irsa" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-role-for-service-accounts-eks?ref=c29ec1ed409683086f63f83ff5b10a6f3c296ef2"

  role_name = "${var.cluster_name}-ebs-csi-driver"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.tags
}

# IAM role for Karpenter controller
module "karpenter_irsa" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-role-for-service-accounts-eks?ref=c29ec1ed409683086f63f83ff5b10a6f3c296ef2"

  role_name                     = "${var.cluster_name}-karpenter"
  attach_karpenter_controller_policy = true

  karpenter_controller_cluster_name = var.cluster_name
  karpenter_controller_node_iam_role_arns = [aws_iam_role.karpenter_node.arn]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${var.karpenter_namespace}:karpenter"]
    }
  }

  tags = local.tags
}

# Attach the custom Karpenter controller policy to the IRSA role
resource "aws_iam_role_policy_attachment" "karpenter_custom_policy" {
  role       = module.karpenter_irsa.iam_role_name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

# IAM role for VPC-CNI
module "vpc_cni_irsa" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-role-for-service-accounts-eks?ref=c29ec1ed409683086f63f83ff5b10a6f3c296ef2"

  role_name = "${var.cluster_name}-vpc-cni"

  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = local.tags
}
