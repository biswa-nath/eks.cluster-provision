# Data source for existing VPC
data "aws_vpc" "existing" {
  count = var.create_vpc ? 0 : 1
  id    = var.vpc_id
}

# Data sources for existing subnets
data "aws_subnets" "private" {
  count = var.create_vpc ? 0 : 1
  
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  
  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}

data "aws_subnets" "public" {
  count = var.create_vpc ? 0 : 1
  
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  
  filter {
    name   = "tag:Name"
    values = ["*public*"]
  }
}

# Get subnet details for existing subnets
data "aws_subnet" "private" {
  count = var.create_vpc ? 0 : length(local.private_subnet_ids)
  id    = local.private_subnet_ids[count.index]
}

data "aws_subnet" "public" {
  count = var.create_vpc ? 0 : length(local.public_subnet_ids)
  id    = local.public_subnet_ids[count.index]
}

# Create new VPC if needed
module "vpc" {
  count   = var.create_vpc ? 1 : 0
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
    "karpenter.sh/discovery"                    = var.cluster_name
  }

  tags = local.tags
}

# Local values to handle both existing and new VPC scenarios
locals {
  vpc_id = var.create_vpc ? module.vpc[0].vpc_id : data.aws_vpc.existing[0].id
  
  # Use provided subnet IDs if available, otherwise discover them
  private_subnet_ids = var.create_vpc ? module.vpc[0].private_subnets : (
    length(var.private_subnet_ids) > 0 ? var.private_subnet_ids : data.aws_subnets.private[0].ids
  )
  
  public_subnet_ids = var.create_vpc ? module.vpc[0].public_subnets : (
    length(var.public_subnet_ids) > 0 ? var.public_subnet_ids : data.aws_subnets.public[0].ids
  )
  
  # VPC CIDR for reference
  vpc_cidr_block = var.create_vpc ? module.vpc[0].vpc_cidr_block : data.aws_vpc.existing[0].cidr_block
}

# Add required tags to existing subnets
resource "aws_ec2_tag" "private_subnet_karpenter_tag" {
  count       = var.create_vpc ? 0 : length(local.private_subnet_ids)
  resource_id = local.private_subnet_ids[count.index]
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}
