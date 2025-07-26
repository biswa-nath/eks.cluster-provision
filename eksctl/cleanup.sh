#!/bin/bash
#
# EKS Cluster with Karpenter Cleanup Script
# This script deletes all resources created by the setup-cluster.sh script
# Resources are deleted in reverse order of creation to ensure proper cleanup
#

# Color definitions
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Function to print colored section headers
print_section() {
    echo -e "\n${BLUE}=========================================================${NC}"
    echo -e "${GREEN}${BOLD}$1${NC}"
    echo -e "${BLUE}=========================================================${NC}\n"
}

# Function to print status messages
print_status() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Function to print error messages
print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to print command execution
print_command() {
    echo -e "${CYAN}[EXEC]${NC} $1"
}

# Function to check command success
check_success() {
    if [ $? -eq 0 ]; then
        print_success "$1"
    else
        print_error "$2"
        # Don't exit on error during cleanup - try to continue with other resources
        return 1
    fi
}

# Check if cluster name file exists
if [ ! -f "cluster-name" ]; then
    print_error "cluster-name file not found. Cannot determine which cluster to delete."
    echo -e "If you know the cluster name, you can run: ${YELLOW}echo \"cluster-name\" > cluster-name${NC} and try again."
    exit 1
fi

# Get cluster name and load environment variables
cluster=$(cat cluster-name)
print_status "Preparing to delete cluster: ${BOLD}${cluster}${NC}"
source ../common/env.sh $cluster

# Display confirmation prompt
echo -e "\n${RED}${BOLD}WARNING: This will delete the EKS cluster and all associated resources.${NC}"
echo -e "${RED}${BOLD}This action cannot be undone.${NC}"
read -p "Are you sure you want to continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Operation cancelled by user"
    exit 0
fi

print_section "STEP 1: Deleting Any Remaining Workloads"
print_status "Checking for and deleting any test deployments..."

# Try to delete the inflate deployment if it exists
print_command "kubectl delete deployment inflate --ignore-not-found=true"
kubectl delete deployment inflate --ignore-not-found=true
print_status "Any test deployments have been cleaned up"

print_section "STEP 2: Deleting Karpenter NodePool and NodeClass"
print_status "Removing Karpenter provisioning resources..."

# Delete Karpenter NodePool and NodeClass
print_command "Deleting Karpenter NodePool and NodeClass from karpenter-nodeclass-nodepool.yaml"
envsubst < ../common/karpenter-nodeclass-nodepool.yaml | kubectl delete -f - --ignore-not-found=true
check_success "Karpenter NodePool and NodeClass deleted successfully" "Failed to delete some Karpenter resources"

print_section "STEP 3: Uninstalling Karpenter"
print_status "Removing Karpenter from the cluster..."

# Uninstall Karpenter using Helm
print_command "helm uninstall karpenter -n ${KARPENTER_NAMESPACE}"
helm uninstall karpenter -n ${KARPENTER_NAMESPACE} 2>/dev/null || true
check_success "Karpenter uninstalled successfully" "Failed to uninstall Karpenter or it was already removed"

print_section "STEP 4: Deleting EKS Cluster"
print_status "Deleting EKS cluster '${CLUSTER_NAME}'..."
print_status "This step may take 10-15 minutes to complete..."

# Delete EKS cluster using eksctl
print_command "Running: eksctl delete cluster with configuration from eks-cluster.yaml"
envsubst < eks-cluster.yaml | eksctl delete cluster -f -
check_success "EKS cluster deleted successfully" "Failed to delete EKS cluster completely"

print_section "STEP 5: Deleting Karpenter CloudFormation Stack"
print_status "Removing Karpenter IAM roles and other AWS resources..."

# Delete CloudFormation stack for Karpenter resources
print_command "aws cloudformation delete-stack --stack-name \"Karpenter-${CLUSTER_NAME}\""
aws cloudformation delete-stack --stack-name "Karpenter-${CLUSTER_NAME}"
check_success "CloudFormation stack deletion initiated" "Failed to initiate CloudFormation stack deletion"

# Wait for CloudFormation stack deletion to complete
print_status "Waiting for CloudFormation stack deletion to complete..."
print_command "aws cloudformation wait stack-delete-complete --stack-name \"Karpenter-${CLUSTER_NAME}\""
aws cloudformation wait stack-delete-complete --stack-name "Karpenter-${CLUSTER_NAME}" 2>/dev/null || true
print_status "CloudFormation stack deletion completed or timed out"

print_section "STEP 6: Cleaning Up Local Files"
print_status "Removing local configuration files..."

# Clean up local files
print_command "Removing cluster-name file"
rm -f cluster-name
check_success "Local files cleaned up" "Failed to clean up some local files"

# Check for any leftover temporary files
if [ -f "${TEMPOUT}" ]; then
    print_command "Removing temporary file ${TEMPOUT}"
    rm -f "${TEMPOUT}"
fi

# Remove timestamp file if it exists
if [ -f "cluster-provision-timestamp.txt" ]; then
    print_command "Removing cluster-provision-timestamp.txt"
    rm -f cluster-provision-timestamp.txt
fi

print_section "Cleanup Complete"
print_success "All resources for cluster '${CLUSTER_NAME}' have been deleted"

# Final verification suggestion
#print_status "For verification, you can check that no resources remain with these commands:"
#echo -e "${YELLOW}aws eks describe-cluster --name \"${CLUSTER_NAME}\" 2>&1 | grep \"ResourceNotFoundException\"${NC}"
#echo -e "${YELLOW}aws cloudformation describe-stacks --stack-name \"Karpenter-${CLUSTER_NAME}\" 2>&1 | grep \"does not exist\"${NC}"
