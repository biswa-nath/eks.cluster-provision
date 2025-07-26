# Outputs for the Karpenter NodePool and EC2NodeClass

# Cluster information from parent state
output "cluster_name" {
  description = "EKS cluster name from parent state"
  value       = local.cluster_name
}

output "region" {
  description = "AWS region from parent state"
  value       = local.region
}

# YAML content for verification
output "karpenter_yaml_content" {
  description = "The processed YAML content with variable substitution"
  value = {
    original_yaml         = local.karpenter_yaml_raw
    nodepool_manifest     = local.nodepool_manifest
    ec2nodeclass_manifest = local.ec2nodeclass_manifest
    ami_alias_version     = local.alias_version
  }
}
