data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# Get the latest AL2023 AMI for ARM64
data "aws_ssm_parameter" "eks_ami_id" {
  name = "/aws/service/eks/optimized-ami/${var.kubernetes_version}/amazon-linux-2023/arm64/standard/recommended/image_id"
}

data "aws_ami" "eks_ami" {
  owners = ["amazon"]
  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.eks_ami_id.value]
  }
}

# Extract the version from the AMI name
data "aws_ami" "eks_ami_details" {
  owners = ["amazon"]
  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.eks_ami_id.value]
  }
}

locals {
  name            = var.cluster_name
  cluster_version = var.kubernetes_version
  
  tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  ami_name = data.aws_ami.eks_ami_details.name
  # Extract version using regex
  ami_version = replace(
    element(
      regexall("v[0-9]+", local.ami_name),
      0
    ),
    "",
    ""
  )
}
