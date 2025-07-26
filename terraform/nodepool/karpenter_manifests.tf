# Karpenter NodePool and EC2NodeClass Manifests using kubernetes_manifest
# This configuration depends on the parent Terraform state for cluster information

# Data source to get Karpenter Helm release from parent state
data "kubernetes_service" "karpenter" {
  metadata {
    name      = "karpenter"
    namespace = "kube-system"
  }
  
  depends_on = [data.terraform_remote_state.cluster]
}

# Apply NodePool manifest
resource "kubernetes_manifest" "karpenter_nodepool" {
  # Dependencies on parent state resources
  depends_on = [
    data.terraform_remote_state.cluster,
    data.kubernetes_service.karpenter
  ]

  manifest = local.nodepool_manifest

  # Wait for the manifest to be applied
  wait {
    condition {
      type   = "Ready"
      status = "True"
    }
  }

  # Handle updates gracefully
  field_manager {
    name            = "terraform"
    force_conflicts = true
  }
}

# Apply EC2NodeClass manifest
resource "kubernetes_manifest" "karpenter_ec2nodeclass" {
  # Dependencies on parent state resources
  depends_on = [
    data.terraform_remote_state.cluster,
    data.kubernetes_service.karpenter
  ]

  manifest = local.ec2nodeclass_manifest

  # Wait for the manifest to be applied
  wait {
    condition {
      type   = "Ready"
      status = "True"
    }
  }

  # Handle updates gracefully
  field_manager {
    name            = "terraform"
    force_conflicts = true
  }
}

# Data source to verify NodePool status
data "kubernetes_resource" "nodepool_status" {
  depends_on = [kubernetes_manifest.karpenter_nodepool]
  
  api_version = local.nodepool_manifest.apiVersion
  kind        = local.nodepool_manifest.kind
  
  metadata {
    name = local.nodepool_manifest.metadata.name
  }
}

# Data source to verify EC2NodeClass status
data "kubernetes_resource" "ec2nodeclass_status" {
  depends_on = [kubernetes_manifest.karpenter_ec2nodeclass]
  
  api_version = local.ec2nodeclass_manifest.apiVersion
  kind        = local.ec2nodeclass_manifest.kind
  
  metadata {
    name = local.ec2nodeclass_manifest.metadata.name
  }
}


