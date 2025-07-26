variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.32"
}

variable "karpenter_namespace" {
  description = "Namespace for Karpenter"
  type        = string
  default     = "kube-system"
}

variable "karpenter_version" {
  description = "Version of Karpenter to install"
  type        = string
  default     = "1.5.2"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones for VPC"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b", "us-east-2c"]
}

variable "private_subnets" {
  description = "Private subnets for VPC"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnets" {
  description = "Public subnets for VPC"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "node_group_instance_types" {
  description = "Instance types for the EKS managed node group"
  type        = list(string)
  default     = ["t4g.small"]
}

variable "node_group_min_size" {
  description = "Minimum size of the node group"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum size of the node group"
  type        = number
  default     = 10
}

variable "node_group_desired_size" {
  description = "Desired size of the node group"
  type        = number
  default     = 2
}

variable "node_group_disk_size" {
  description = "Disk size for the node group instances"
  type        = number
  default     = 20
}

variable "karpenter_instance_types" {
  description = "Instance types for Karpenter to use"
  type        = list(string)
  default     = ["t4g.small", "t4g.medium", "t4g.large", "t4g.xlarge", "t4g.2xlarge"]
}
