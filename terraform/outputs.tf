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
  value       = module.vpc.vpc_id
}

output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = module.vpc.vpc_arn
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "private_subnet_arns" {
  description = "List of ARNs of private subnets"
  value       = module.vpc.private_subnet_arns
}

output "public_subnet_arns" {
  description = "List of ARNs of public subnets"
  value       = module.vpc.public_subnet_arns
}

output "nat_gateway_ids" {
  description = "List of IDs of the NAT Gateways"
  value       = module.vpc.natgw_ids
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = module.vpc.igw_id
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

# EBS CSI Driver Outputs
output "ebs_csi_irsa_arn" {
  description = "The Amazon Resource Name (ARN) specifying the IAM role for EBS CSI driver"
  value       = module.ebs_csi_irsa.iam_role_arn
}

output "ebs_csi_irsa_name" {
  description = "The name of the IAM role for EBS CSI driver"
  value       = module.ebs_csi_irsa.iam_role_name
}

# VPC CNI Outputs
output "vpc_cni_irsa_arn" {
  description = "The Amazon Resource Name (ARN) specifying the IAM role for VPC CNI"
  value       = module.vpc_cni_irsa.iam_role_arn
}

output "vpc_cni_irsa_name" {
  description = "The name of the IAM role for VPC CNI"
  value       = module.vpc_cni_irsa.iam_role_name
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
    vpc_id          = module.vpc.vpc_id
    private_subnets = module.vpc.private_subnets
    public_subnets  = module.vpc.public_subnets
  }
}
