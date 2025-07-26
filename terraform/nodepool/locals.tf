# Local values derived from parent Terraform state
locals {
  # Cluster information from parent state
  cluster_name = data.terraform_remote_state.cluster.outputs.cluster_name
  region       = data.terraform_remote_state.cluster.outputs.cluster_info.region
  
  # AMI alias version
  alias_version = data.external.ami_alias_version.result["result"]

  # Process the YAML template with variable substitution
  karpenter_yaml_raw = templatefile("${path.module}/../../common/karpenter-nodeclass-nodepool.yaml", {
    CLUSTER_NAME   = local.cluster_name
    ALIAS_VERSION  = local.alias_version
  })
  
  # Split the YAML content into individual documents and parse them
  karpenter_docs = [
    for doc in split("---", local.karpenter_yaml_raw) : 
    yamldecode(doc) if trimspace(doc) != ""
  ]
  
  # Extract individual manifests
  nodepool_manifest     = local.karpenter_docs[0]
  ec2nodeclass_manifest = local.karpenter_docs[1]
}
