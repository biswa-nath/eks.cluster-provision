# Karpenter Node IAM Role
resource "aws_iam_role" "karpenter_node" {
  name = "KarpenterNodeRole-${var.cluster_name}"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.${data.aws_partition.current.dns_suffix}"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.tags
}

# Attach required policies to Karpenter Node IAM Role
resource "aws_iam_role_policy_attachment" "karpenter_node_eks_cni" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_eks_worker" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ecr_pull" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ssm" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Karpenter Controller Policy
resource "aws_iam_policy" "karpenter_controller" {
  name = "KarpenterControllerPolicy-${var.cluster_name}"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowScopedEC2InstanceAccessActions"
        Effect = "Allow"
        Resource = [
          "arn:${data.aws_partition.current.partition}:ec2:${var.region}::image/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.region}::snapshot/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:security-group/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:subnet/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:capacity-reservation/*"
        ]
        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet"
        ]
      },
      {
        Sid    = "AllowScopedEC2LaunchTemplateAccessActions"
        Effect = "Allow"
        Resource = "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:launch-template/*"
        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet"
        ]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
          }
          StringLike = {
            "aws:ResourceTag/karpenter.sh/nodepool" = "*"
          }
        }
      },
      {
        Sid    = "AllowScopedEC2InstanceActionsWithTags"
        Effect = "Allow"
        Resource = [
          "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:fleet/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:instance/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:volume/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:network-interface/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:launch-template/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:spot-instances-request/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:capacity-reservation/*"
        ]
        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate"
        ]
        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
            "aws:RequestTag/eks:eks-cluster-name" = var.cluster_name
          }
          StringLike = {
            "aws:RequestTag/karpenter.sh/nodepool" = "*"
          }
        }
      },
      {
        Sid    = "AllowScopedResourceCreationTagging"
        Effect = "Allow"
        Resource = [
          "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:fleet/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:instance/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:volume/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:network-interface/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:launch-template/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:spot-instances-request/*"
        ]
        Action = "ec2:CreateTags"
        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
            "aws:RequestTag/eks:eks-cluster-name" = var.cluster_name
            "ec2:CreateAction" = [
              "RunInstances",
              "CreateFleet",
              "CreateLaunchTemplate"
            ]
          }
          StringLike = {
            "aws:RequestTag/karpenter.sh/nodepool" = "*"
          }
        }
      },
      {
        Sid    = "AllowScopedResourceTagging"
        Effect = "Allow"
        Resource = "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:instance/*"
        Action = "ec2:CreateTags"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
          }
          StringLike = {
            "aws:ResourceTag/karpenter.sh/nodepool" = "*"
          }
          StringEqualsIfExists = {
            "aws:RequestTag/eks:eks-cluster-name" = var.cluster_name
          },
          "ForAllValues:StringEquals" = {
            "aws:TagKeys" = [
              "eks:eks-cluster-name",
              "karpenter.sh/nodeclaim",
              "Name"
            ]
          }
        }
      },
      {
        Sid    = "AllowScopedDeletion"
        Effect = "Allow"
        Resource = [
          "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:instance/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:launch-template/*"
        ]
        Action = [
          "ec2:TerminateInstances",
          "ec2:DeleteLaunchTemplate"
        ]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
          }
          StringLike = {
            "aws:ResourceTag/karpenter.sh/nodepool" = "*"
          }
        }
      },
      {
        Sid    = "AllowRegionalReadActions"
        Effect = "Allow"
        Resource = "*"
        Action = [
          "ec2:DescribeCapacityReservations",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets"
        ]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.region
          }
        }
      },
      {
        Sid    = "AllowSSMReadActions"
        Effect = "Allow"
        Resource = "arn:${data.aws_partition.current.partition}:ssm:${var.region}::parameter/aws/service/*"
        Action = "ssm:GetParameter"
      },
      {
        Sid    = "AllowPricingReadActions"
        Effect = "Allow"
        Resource = "*"
        Action = "pricing:GetProducts"
      },
      {
        Sid    = "AllowInterruptionQueueActions"
        Effect = "Allow"
        Resource = aws_sqs_queue.karpenter_interruption.arn
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage"
        ]
      },
      {
        Sid    = "AllowPassingInstanceRole"
        Effect = "Allow"
        Resource = aws_iam_role.karpenter_node.arn
        Action = "iam:PassRole"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = [
              "ec2.amazonaws.com",
              "ec2.amazonaws.com.cn"
            ]
          }
        }
      },
      {
        Sid    = "AllowScopedInstanceProfileCreationActions"
        Effect = "Allow"
        Resource = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:instance-profile/*"
        Action = [
          "iam:CreateInstanceProfile"
        ]
        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
            "aws:RequestTag/eks:eks-cluster-name" = var.cluster_name
            "aws:RequestTag/topology.kubernetes.io/region" = var.region
          }
          StringLike = {
            "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass" = "*"
          }
        }
      },
      {
        Sid    = "AllowScopedInstanceProfileTagActions"
        Effect = "Allow"
        Resource = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:instance-profile/*"
        Action = [
          "iam:TagInstanceProfile"
        ]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
            "aws:ResourceTag/topology.kubernetes.io/region" = var.region
            "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
            "aws:RequestTag/eks:eks-cluster-name" = var.cluster_name
            "aws:RequestTag/topology.kubernetes.io/region" = var.region
          }
          StringLike = {
            "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass" = "*"
            "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass" = "*"
          }
        }
      },
      {
        Sid    = "AllowScopedInstanceProfileActions"
        Effect = "Allow"
        Resource = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:instance-profile/*"
        Action = [
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:DeleteInstanceProfile"
        ]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
            "aws:ResourceTag/topology.kubernetes.io/region" = var.region
          }
          StringLike = {
            "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass" = "*"
          }
        }
      },
      {
        Sid    = "AllowInstanceProfileReadActions"
        Effect = "Allow"
        Resource = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:instance-profile/*"
        Action = "iam:GetInstanceProfile"
      },
      {
        Sid    = "AllowAPIServerEndpointDiscovery"
        Effect = "Allow"
        Resource = "arn:${data.aws_partition.current.partition}:eks:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
        Action = "eks:DescribeCluster"
      }
    ]
  })

  tags = local.tags
}

# Karpenter Interruption SQS Queue
resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = var.cluster_name
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true

  tags = local.tags
}

# Karpenter Interruption Queue Policy
resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.url

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "EC2InterruptionPolicy"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "events.amazonaws.com",
            "sqs.amazonaws.com"
          ]
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.karpenter_interruption.arn
      },
      {
        Sid       = "DenyHTTP"
        Effect    = "Deny"
        Action    = "sqs:*"
        Resource  = aws_sqs_queue.karpenter_interruption.arn
        Condition = {
          Bool = {
            "aws:SecureTransport" = false
          }
        }
        Principal = "*"
      }
    ]
  })
}

# EventBridge Rules for Karpenter
resource "aws_cloudwatch_event_rule" "scheduled_change" {
  name        = "${var.cluster_name}-scheduled-change"
  description = "Capture AWS Health events for EC2 scheduled changes"

  event_pattern = jsonencode({
    source      = ["aws.health"]
    detail-type = ["AWS Health Event"]
  })

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "scheduled_change" {
  rule      = aws_cloudwatch_event_rule.scheduled_change.name
  target_id = "KarpenterInterruptionQueueTarget"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "spot_interruption" {
  name        = "${var.cluster_name}-spot-interruption"
  description = "Capture EC2 Spot Instance Interruption Warnings"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "spot_interruption" {
  rule      = aws_cloudwatch_event_rule.spot_interruption.name
  target_id = "KarpenterInterruptionQueueTarget"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "rebalance" {
  name        = "${var.cluster_name}-rebalance"
  description = "Capture EC2 Instance Rebalance Recommendations"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "rebalance" {
  rule      = aws_cloudwatch_event_rule.rebalance.name
  target_id = "KarpenterInterruptionQueueTarget"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "instance_state_change" {
  name        = "${var.cluster_name}-instance-state-change"
  description = "Capture EC2 Instance State-change Notifications"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
  })

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "instance_state_change" {
  rule      = aws_cloudwatch_event_rule.instance_state_change.name
  target_id = "KarpenterInterruptionQueueTarget"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}
