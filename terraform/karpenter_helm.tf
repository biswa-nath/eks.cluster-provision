resource "helm_release" "karpenter" {
  depends_on = [module.eks]

  namespace        = var.karpenter_namespace
  create_namespace = false

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_version

  set = [
  {
    name  = "settings.clusterName"
    value = var.cluster_name
  },
  {
    name  = "settings.interruptionQueue"
    value = var.cluster_name
  },
  {
    name  = "controller.resources.requests.cpu"
    value = "500m"
  },
  {
    name  = "controller.resources.requests.memory"
    value = "500Mi"
  },
  {
    name  = "controller.resources.limits.cpu"
    value = "500m"
  },
  {
    name  = "controller.resources.limits.memory"
    value = "500Mi"
  },
  {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter_irsa.iam_role_arn
  }
  ]

  wait = true
}
