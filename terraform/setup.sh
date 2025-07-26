#!/bin/bash

# EKS Cluster Setup Script
# This script creates an EKS cluster and configures Karpenter nodepools using Terraform

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command_exists terraform; then
        print_error "Terraform is not installed. Please install Terraform first."
        exit 1
    fi
    
    if ! command_exists aws; then
        print_error "AWS CLI is not installed. Please install AWS CLI first."
        exit 1
    fi
    
    if ! command_exists kubectl; then
        print_warning "kubectl is not installed. You'll need it to interact with the cluster later."
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_success "Prerequisites check completed"
}

# Function to run terraform commands with error handling
run_terraform() {
    local action=$1
    local directory=$2
    
    print_status "Running terraform $action in $directory..."
    
    cd "$directory"
    
    case $action in
        "init")
            terraform init
            ;;
        "plan")
            terraform plan
            ;;
        "apply")
            terraform apply -auto-approve
            ;;
        "destroy")
            terraform destroy -auto-approve
            ;;
        *)
            print_error "Unknown terraform action: $action"
            exit 1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        print_success "Terraform $action completed successfully in $directory"
    else
        print_error "Terraform $action failed in $directory"
        exit 1
    fi
}

# Function to update kubeconfig
update_kubeconfig() {
    print_status "Updating kubeconfig..."
    
    # Get cluster name from terraform output
    CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "default")
    #REGION=$(grep 'region' terraform.tfvars | cut -d'"' -f2 2>/dev/null || echo "us-east-2")
    
    if [ -z "$CLUSTER_NAME" ]; then
        print_error "Could not determine cluster name from terraform.tfvars"
        exit 1
    fi
    
    #aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"
    eks_update_kubeconfig=$(terraform output -raw configure_kubectl)
    eval "$eks_update_kubeconfig"
    if [ $? -eq 0 ]; then
        print_success "Kubeconfig updated for cluster: $CLUSTER_NAME"
    else
        print_error "Failed to update kubeconfig"
        exit 1
    fi
}

# Function to verify cluster status
verify_cluster() {
    print_status "Verifying cluster status..."
    
    if command_exists kubectl; then
        kubectl get nodes
        kubectl get pods -A
        print_success "Cluster verification completed"
    else
        print_warning "kubectl not available, skipping cluster verification"
    fi
}

patch_deployment_metrics_server() {
    print_status "Patching deployment metrics-server by updating port to 10250..."

    if command_exists kubectl; then
        kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/args",
    "value": [
      "--cert-dir=/tmp",
      "--secure-port=10250",
      "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname",
      "--kubelet-use-node-status-port",
      "--metric-resolution=15s"
    ]
  },
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/ports/0/containerPort",
    "value": 10250
  }
]'
    else
        print_warning "kubectl not available, skipping metrics-server patch"
    fi
}

# Main execution
main() {
    local action=${1:-"apply"}
    local skip_nodepool=${2:-"false"}
    
    print_status "Starting EKS cluster setup with action: $action"
    
    # Get the script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    MAIN_DIR="$SCRIPT_DIR"
    NODEPOOL_DIR="$SCRIPT_DIR/nodepool"
    
    case $action in
        "init")
            check_prerequisites
            run_terraform "init" "$MAIN_DIR"
            if [ "$skip_nodepool" != "true" ] && [ -d "$NODEPOOL_DIR" ]; then
                run_terraform "init" "$NODEPOOL_DIR"
            fi
            ;;
        "plan")
            check_prerequisites
            run_terraform "plan" "$MAIN_DIR"
            if [ "$skip_nodepool" != "true" ] && [ -d "$NODEPOOL_DIR" ]; then
                run_terraform "plan" "$NODEPOOL_DIR"
            fi
            ;;
        "apply")
            check_prerequisites
            
            # Step 1: Initialize and apply main cluster
            print_status "=== Phase 1: Creating EKS Cluster ==="
            run_terraform "init" "$MAIN_DIR"
            run_terraform "apply" "$MAIN_DIR"
            
            # Step 2: Update kubeconfig
            update_kubeconfig

            # Step 3: Apply nodepool configuration if directory exists
            if [ "$skip_nodepool" != "true" ] && [ -d "$NODEPOOL_DIR" ]; then
                print_status "=== Phase 2: Configuring Karpenter Nodepools ==="
                run_terraform "init" "$NODEPOOL_DIR"
                run_terraform "apply" "$NODEPOOL_DIR"
            else
                print_warning "Nodepool directory not found or skipped, skipping nodepool configuration"
            fi
            
            # Step 4: Verify cluster
            verify_cluster

            # Step 5: Fix metrics-server deployment
            patch_deployment_metrics_server

            print_success "=== EKS Cluster Setup Complete ==="
            print_status "Cluster is ready for use!"
            ;;
        "destroy")
            print_warning "=== Destroying EKS Cluster ==="
            print_warning "This will destroy all resources. Are you sure? (y/N)"
            read -r confirmation
            if [[ $confirmation =~ ^[Yy]$ ]]; then
                # Destroy in reverse order
                if [ "$skip_nodepool" != "true" ] && [ -d "$NODEPOOL_DIR" ]; then
                    print_status "Destroying nodepool resources..."
                    run_terraform "destroy" "$NODEPOOL_DIR"
                fi
                
                print_status "Destroying main cluster resources..."
                run_terraform "destroy" "$MAIN_DIR"
                
                print_success "Cluster destroyed successfully"
            else
                print_status "Destroy cancelled"
            fi
            ;;
        *)
            print_error "Unknown action: $action"
            echo "Usage: $0 [init|plan|apply|destroy] [skip_nodepool]"
            echo "  init         - Initialize Terraform in both directories"
            echo "  plan         - Plan Terraform changes in both directories"
            echo "  apply        - Apply Terraform changes (default)"
            echo "  destroy      - Destroy all resources"
            echo "  skip_nodepool - Skip nodepool operations (optional second parameter)"
            exit 1
            ;;
    esac
}

# Handle script interruption
trap 'print_error "Script interrupted"; exit 1' INT TERM

# Run main function with all arguments
main "$@"
