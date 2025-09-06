# EKS Cluster Outputs
output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

# CloudWatch Logs and KMS Outputs
output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for EKS cluster"
  value       = aws_cloudwatch_log_group.eks_cluster.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for EKS cluster"
  value       = aws_cloudwatch_log_group.eks_cluster.arn
}

output "cloudwatch_logs_kms_key_id" {
  description = "KMS key ID used for CloudWatch logs encryption"
  value       = aws_kms_key.cloudwatch_logs.key_id
}

output "cloudwatch_logs_kms_key_arn" {
  description = "KMS key ARN used for CloudWatch logs encryption"
  value       = aws_kms_key.cloudwatch_logs.arn
}

output "cluster_version" {
  description = "The Kubernetes version for the EKS cluster"
  value       = module.eks.cluster_version
}

output "cluster_platform_version" {
  description = "Platform version for the EKS cluster"
  value       = module.eks.cluster_platform_version
}

output "cluster_status" {
  description = "Status of the EKS cluster. One of `CREATING`, `ACTIVE`, `DELETING`, `FAILED`"
  value       = module.eks.cluster_status
}

output "cluster_security_group_id" {
  description = "Cluster security group that was created by Amazon EKS for the cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = module.eks.cluster_iam_role_name
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN associated with EKS cluster"
  value       = module.eks.cluster_iam_role_arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_primary_security_group_id" {
  description = "Cluster security group that was created by Amazon EKS for the cluster. Managed node groups use this security group for control-plane-to-data-plane communication. Referred to as 'Cluster security group' in the EKS console"
  value       = module.eks.cluster_primary_security_group_id
}

# OIDC Provider Outputs
output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider if enabled"
  value       = module.eks.oidc_provider_arn
}

# EKS Managed Node Group Outputs
output "eks_managed_node_groups" {
  description = "Map of attribute maps for all EKS managed node groups created"
  value       = module.eks.eks_managed_node_groups
}

output "eks_managed_node_groups_autoscaling_group_names" {
  description = "List of the autoscaling group names created by EKS managed node groups"
  value       = module.eks.eks_managed_node_groups_autoscaling_group_names
}

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC where the cluster and its nodes will be provisioned"
  value       = local.vpc_id
}

output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = var.create_vpc ? module.vpc[0].vpc_arn : data.aws_vpc.existing[0].arn
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = local.vpc_cidr_block
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = local.private_subnet_ids
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = local.public_subnet_ids
}

output "private_subnet_arns" {
  description = "List of ARNs of private subnets"
  value       = var.create_vpc ? module.vpc[0].private_subnet_arns : [for subnet in data.aws_subnet.private : subnet.arn]
}

output "public_subnet_arns" {
  description = "List of ARNs of public subnets"
  value       = var.create_vpc ? module.vpc[0].public_subnet_arns : [for subnet in data.aws_subnet.public : subnet.arn]
}

output "nat_gateway_ids" {
  description = "List of IDs of the NAT Gateways"
  value       = var.create_vpc ? module.vpc[0].natgw_ids : []
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = var.create_vpc ? module.vpc[0].igw_id : null
}

# Karpenter Outputs
output "karpenter_irsa_arn" {
  description = "The Amazon Resource Name (ARN) specifying the IAM role for Karpenter"
  value       = module.karpenter_irsa.iam_role_arn
}

output "karpenter_irsa_name" {
  description = "The name of the IAM role for Karpenter"
  value       = module.karpenter_irsa.iam_role_name
}

output "karpenter_node_iam_role_name" {
  description = "The name of the IAM role for Karpenter nodes"
  value       = aws_iam_role.karpenter_node.name
}

output "karpenter_node_iam_role_arn" {
  description = "The Amazon Resource Name (ARN) specifying the IAM role for Karpenter nodes"
  value       = aws_iam_role.karpenter_node.arn
}

output "karpenter_controller_policy_arn" {
  description = "The ARN of the Karpenter controller policy"
  value       = aws_iam_policy.karpenter_controller.arn
}

# Configuration Commands
output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${var.region} update-kubeconfig --name ${module.eks.cluster_name}"
}

output "cluster_info" {
  description = "Cluster information for connecting and managing the EKS cluster"
  value = {
    cluster_name     = module.eks.cluster_name
    cluster_endpoint = module.eks.cluster_endpoint
    cluster_version  = module.eks.cluster_version
    region          = var.region
    vpc_id          = local.vpc_id
    private_subnets = local.private_subnet_ids
    public_subnets  = local.public_subnet_ids
  }
}
