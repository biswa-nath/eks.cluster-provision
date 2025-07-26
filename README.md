# EKS Cluster with Karpenter

This project sets up an EKS cluster with Karpenter for automatic node provisioning. The cluster starts with minimal nodes and scales up automatically when workloads are deployed.

We provide two approaches for creating the EKS cluster with Karpenter:
1. **eksctl** - Using eksctl with YAML configuration
2. **Terraform** - Using Terraform for Infrastructure as Code

## Project Structure

```
/
├── common/                           # Shared resources
│   ├── karpenter-nodeclass-nodepool.yaml  # Karpenter EC2NodeClass and NodePool
│   ├── env.sh                        # Environment variables
│   └── get_ami_version.sh           # Helper script for AMI version
├── eksctl/                          # eksctl approach
│   ├── eks-cluster.yaml             # eksctl cluster configuration
│   ├── setup.sh                     # Setup script
│   └── cleanup.sh                   # Cleanup script
└── terraform/                       # Terraform approach
    ├── *.tf files                   # Terraform configuration files
    ├── setup.sh                     # Setup script
    └── nodepool/                    # Karpenter NodePool configurations
```

## Karpenter Details

https://karpenter.sh/v1.5/getting-started/getting-started-with-karpenter/

## Deployment Options

### Option 1: Using eksctl

Navigate to the eksctl directory and run the setup script:

```bash
cd eksctl
./setup.sh [cluster-name]
```

This approach:
- Uses eksctl with YAML configuration (`eks-cluster.yaml`)
- Creates Karpenter resources - SQS queue, EventBridge rules, IAM role for Karpenter launched nodes
- Creates an EKS cluster in us-east-2 with Kubernetes 1.32
- Sets up a minimal managed node group with 2 t4g.small instances to run Karpenter controller
- Configures required IAM roles and OIDC provider for Karpenter
- Installs Karpenter via Helm
- Applies EC2NodeClass and NodePool from `common/karpenter-nodeclass-nodepool.yaml`

### Option 2: Using Terraform

Navigate to the terraform directory and run the setup script:

```bash
cd terraform
./setup.sh
```

This approach:
- Uses Terraform for Infrastructure as Code
- Creates all AWS resources including VPC, EKS cluster, and Karpenter prerequisites
- Manages the complete infrastructure lifecycle through Terraform state
- Installs Karpenter via Helm provider
- Applies EC2NodeClass and NodePool configurations
- Provides better resource management and state tracking

#### Terraform Configuration Files

- `main.tf` - Main Terraform configuration
- `eks.tf` - EKS cluster configuration
- `vpc.tf` - VPC and networking setup
- `karpenter_resources.tf` - Karpenter IAM roles, SQS, EventBridge rules
- `karpenter_helm.tf` - Karpenter Helm chart installation
- `variables.tf` - Input variables
- `outputs.tf` - Output values
- `versions.tf` - Provider version constraints
- `provider.tf` - Provider configurations
- `terraform.tfvars` - Variable values

## Testing Auto-scaling

After deploying with either approach, test auto-scaling:

```bash
kubectl create deployment inflate --image=public.ecr.aws/eks-distro/kubernetes/pause:3.7 --replicas=0
kubectl scale deployment inflate --replicas=5
```

Karpenter will automatically provision t4g.* instances to accommodate the workload.

## Cleanup

### For eksctl approach:
```bash
cd eksctl
./cleanup.sh
```

### For Terraform approach:
```bash
cd terraform
# Delete the sample workload first
kubectl delete deployment inflate --ignore-not-found=true
# Then destroy Terraform resources
./setup.sh destroy
```

## Common Configuration

Both approaches use the shared Karpenter configuration from `common/karpenter-nodeclass-nodepool.yaml` which defines:
- **EC2NodeClass**: Specifies the AMI family, instance types, and security groups
- **NodePool**: Defines the node provisioning requirements and limits
