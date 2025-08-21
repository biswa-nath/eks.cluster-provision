# KMS key for CloudWatch logs encryption
resource "aws_kms_key" "cloudwatch_logs" {
  description             = "KMS key for EKS CloudWatch logs encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnEquals = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.cluster_name}/cluster"
          }
        }
      }
    ]
  })

  tags = merge(local.tags, {
    Name = "${var.cluster_name}-cloudwatch-logs-kms"
  })
}

resource "aws_kms_alias" "cloudwatch_logs" {
  name          = "alias/${var.cluster_name}-cloudwatch-logs"
  target_key_id = aws_kms_key.cloudwatch_logs.key_id
}

# Create CloudWatch log group explicitly with KMS encryption
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.cloudwatch_logs.arn

  tags = merge(local.tags, {
    Name = "/aws/eks/${var.cluster_name}/cluster"
  })
}

# Get current region for KMS policy
data "aws_region" "current" {}

# Custom IAM role for EKS managed node group to avoid for_each issues
resource "aws_iam_role" "node_group_role" {
  name = "${var.cluster_name}-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

# Attach required policies to the custom node group role
resource "aws_iam_role_policy_attachment" "node_group_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group_role.name
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group_role.name
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group_role.name
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                   = var.cluster_name
  cluster_version                = var.kubernetes_version
  
  # Secure endpoint access configuration
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_private_access      = var.cluster_endpoint_private_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnet_ids

  # Disable EKS module's CloudWatch log group creation since we're creating it explicitly
  create_cloudwatch_log_group = false

  # Enable all control plane logging types for security and compliance
  cluster_enabled_log_types = var.cluster_enabled_log_types

  # Ensure the log group exists before creating the cluster
  depends_on = [aws_cloudwatch_log_group.eks_cluster]

  # Enable OIDC provider for the cluster
  enable_irsa = true

  # Configure access entries 
  enable_cluster_creator_admin_permissions = true

  # Configure node security group with restrictive egress rules
  node_security_group_enable_recommended_rules = false
  node_security_group_additional_rules = {
    # Allow egress to VPC CIDR for internal communication
    egress_vpc = {
      description = "Allow egress to VPC CIDR"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = [data.aws_vpc.existing[0].cidr_block]
    }
    # Allow HTTPS egress for package updates and container registry access
    egress_https = {
      description = "Allow HTTPS egress"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
    # Allow HTTP egress for package updates
    egress_http = {
      description = "Allow HTTP egress"
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
    # Allow DNS egress
    egress_dns_tcp = {
      description = "Allow DNS TCP egress"
      protocol    = "tcp"
      from_port   = 53
      to_port     = 53
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
    egress_dns_udp = {
      description = "Allow DNS UDP egress"
      protocol    = "udp"
      from_port   = 53
      to_port     = 53
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
    # Allow NTP egress
    egress_ntp = {
      description = "Allow NTP egress"
      protocol    = "udp"
      from_port   = 123
      to_port     = 123
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
    # Allow node-to-node kubelet access for metrics-server
    ingress_node_kubelet = {
      description = "Node to node kubelet for metrics-server"
      protocol    = "tcp"
      from_port   = 10250
      to_port     = 10250
      type        = "ingress"
      self        = true
    }
  }

  # Configure cluster security group to make attachment explicit
  cluster_security_group_additional_rules = {
    # Allow ingress from nodes to cluster API
    ingress_nodes_443 = {
      description                = "Node groups to cluster API"
      protocol                   = "tcp"
      from_port                  = 443
      to_port                    = 443
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  # EKS Managed Node Group with custom IAM role
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

      # Configure metadata options to comply with security requirements
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
        instance_metadata_tags      = "disabled"
      }

      # Use our custom IAM role to avoid for_each issues
      create_iam_role = false
      iam_role_arn    = aws_iam_role.node_group_role.arn

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
    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  tags = local.tags
}

# AWS Auth ConfigMap for Node Authentication
# This is needed because EKS Access Entries don't support system: groups
# which are required for node authentication. This ConfigMap allows both
# managed node group nodes and Karpenter-launched nodes to join the cluster.

resource "kubernetes_config_map_v1_data" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      # Managed Node Group Role
      {
        rolearn  = aws_iam_role.node_group_role.arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups = [
          "system:bootstrappers",
          "system:nodes"
        ]
      },
      # Karpenter Node Role
      {
        rolearn  = aws_iam_role.karpenter_node.arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups = [
          "system:bootstrappers",
          "system:nodes"
        ]
      }
    ])
  }

  force = true

  depends_on = [
    module.eks,
    aws_iam_role.node_group_role,
    aws_iam_role.karpenter_node
  ]
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
