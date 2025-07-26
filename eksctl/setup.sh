#!/bin/bash
#
# EKS Cluster with Karpenter Setup Script
# This script creates an EKS cluster with Karpenter for automatic node provisioning
# The cluster starts with minimal nodes and scales up automatically when workloads are deployed
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
        exit 1
    fi
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check for required commands
    for cmd in aws eksctl kubectl helm envsubst curl; do
        if ! command -v $cmd &> /dev/null; then
            print_error "$cmd is required but not installed. Please install it and try again."
            exit 1
        fi
    done
    
    # Check AWS CLI configuration
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured properly. Please configure it with 'aws configure' and try again."
        exit 1
    fi
    
    print_success "All prerequisites are satisfied"
}

# Check if cluster name is provided
if [ -z "$1" ]; then
    print_error "Cluster name not provided!"
    echo -e "Usage: ${YELLOW}$0 <cluster-name>${NC}"
    exit 1
fi

# Save cluster name for reference
echo $1 > cluster-name
print_status "Setting up cluster: ${BOLD}$1${NC}"

# Check prerequisites
check_prerequisites

# Load environment variables
print_status "Loading environment variables from env.sh..."
source ../common/env.sh $1

# Display configuration summary
print_section "Configuration Summary"
echo -e "Cluster Name:       ${BOLD}${CLUSTER_NAME}${NC}"
echo -e "AWS Region:         ${BOLD}${AWS_DEFAULT_REGION}${NC}"
echo -e "Kubernetes Version: ${BOLD}${K8S_VERSION}${NC}"
echo -e "Karpenter Version:  ${BOLD}${KARPENTER_VERSION}${NC}"
echo -e "AWS Account ID:     ${BOLD}${AWS_ACCOUNT_ID}${NC}"

# Confirm before proceeding
echo -e "\n${YELLOW}This will create AWS resources that may incur costs.${NC}"
read -p "Do you want to continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Operation cancelled by user"
    exit 0
fi

print_section "STEP 1: Creating Karpenter Infrastructure Resources"
print_status "Creating Karpenter node role, SQS queue, and EventBridge rules..."

# Download CloudFormation template for Karpenter resources
print_command "Downloading Karpenter CloudFormation template..."
curl -fsSL https://raw.githubusercontent.com/aws/karpenter-provider-aws/v"${KARPENTER_VERSION}"/website/content/en/preview/getting-started/getting-started-with-karpenter/cloudformation.yaml > "${TEMPOUT}" 
check_success "Template downloaded successfully" "Failed to download Karpenter CloudFormation template"

# Deploy CloudFormation stack for Karpenter resources
print_command "Deploying CloudFormation stack 'Karpenter-${CLUSTER_NAME}'..."
aws cloudformation deploy --stack-name "Karpenter-${CLUSTER_NAME}" \
    --template-file "${TEMPOUT}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides "ClusterName=${CLUSTER_NAME}"
check_success "Karpenter infrastructure resources created successfully" "Failed to create Karpenter infrastructure resources"

print_section "STEP 2: Creating EKS Cluster"
print_status "Creating EKS cluster with Kubernetes ${K8S_VERSION} in ${AWS_DEFAULT_REGION}..."
print_status "This will create a minimal managed node group with t4g.small instances"
print_status "This step may take 15-20 minutes to complete..."

# Create EKS cluster using eksctl
print_command "Running: eksctl create cluster with configuration from eks-cluster.yaml"
envsubst < eks-cluster.yaml | eksctl create cluster -f - --set-kubeconfig-context
check_success "EKS cluster '${CLUSTER_NAME}' created successfully" "Failed to create EKS cluster"

# Get cluster endpoint and Karpenter IAM role ARN
print_status "Retrieving cluster information..."
export CLUSTER_ENDPOINT="$(aws eks describe-cluster --name "${CLUSTER_NAME}" --query "cluster.endpoint" --output text)"
export KARPENTER_IAM_ROLE_ARN="arn:${AWS_PARTITION}:iam::${AWS_ACCOUNT_ID}:role/${CLUSTER_NAME}-karpenter"

print_status "Cluster endpoint: ${CLUSTER_ENDPOINT}"
print_status "Karpenter IAM role ARN: ${KARPENTER_IAM_ROLE_ARN}"

# Verify cluster connectivity
print_command "Verifying cluster connectivity..."
kubectl get nodes
check_success "Successfully connected to the cluster" "Failed to connect to the cluster"

print_section "STEP 3: Installing Karpenter"
print_status "Preparing to install Karpenter ${KARPENTER_VERSION}..."

# Logout of helm registry to perform an unauthenticated pull against the public ECR
print_command "Logging out of helm registry..."
helm registry logout public.ecr.aws

# Install Karpenter using Helm
print_status "Installing Karpenter in namespace '${KARPENTER_NAMESPACE}'..."
print_command "Running: helm upgrade --install karpenter..."
helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
    --version "${KARPENTER_VERSION}" \
    --namespace "${KARPENTER_NAMESPACE}" \
    --set "settings.clusterName=${CLUSTER_NAME}" \
    --set "settings.interruptionQueue=${CLUSTER_NAME}" \
    --set controller.resources.requests.cpu=500m \
    --set controller.resources.requests.memory=500Mi \
    --set controller.resources.limits.cpu=500m \
    --set controller.resources.limits.memory=500Mi \
    --wait
check_success "Karpenter installed successfully" "Failed to install Karpenter"

# Verify Karpenter installation
print_command "Verifying Karpenter installation..."
kubectl get pods -n ${KARPENTER_NAMESPACE} | grep karpenter
check_success "Karpenter pods are running" "Karpenter pods are not running properly"

print_section "STEP 4: Configuring Karpenter Resources"
print_status "Creating EC2NodeClass and NodePool for Karpenter..."

# Apply Karpenter NodeClass and NodePool configuration
print_command "Applying Karpenter configuration from karpenter-nodeclass-nodepool.yaml"
envsubst < ../common/karpenter-nodeclass-nodepool.yaml | kubectl apply -f -
check_success "Karpenter EC2NodeClass and NodePool created successfully" "Failed to create Karpenter EC2NodeClass and NodePool"

# Verify Karpenter configuration
print_command "Verifying Karpenter configuration..."
kubectl get ec2nodeclasses,nodepools
check_success "Karpenter configuration verified" "Could not verify Karpenter configuration"

print_section "EKS Cluster Setup Complete"
print_success "EKS cluster '${CLUSTER_NAME}' with Karpenter ${KARPENTER_VERSION} has been successfully provisioned"

# Display cluster information
echo -e "\n${BOLD}Cluster Information:${NC}"
echo -e "Cluster Name:    ${BOLD}${CLUSTER_NAME}${NC}"
echo -e "Kubernetes:      ${BOLD}${K8S_VERSION}${NC}"
echo -e "Region:          ${BOLD}${AWS_DEFAULT_REGION}${NC}"
echo -e "Endpoint:        ${BOLD}${CLUSTER_ENDPOINT}${NC}"

# Display testing instructions
print_section "Testing Auto-scaling"
print_status "To test auto-scaling, run the following commands:"
echo -e "${YELLOW}kubectl create deployment inflate --image=public.ecr.aws/eks-distro/kubernetes/pause:3.7 --replicas=0${NC}"
echo -e "${YELLOW}kubectl scale deployment inflate --replicas=5${NC}"
echo -e "\nKarpenter will automatically provision t4g.* instances to accommodate the workload."

# Display cleanup instructions
print_section "Cleanup Instructions"
print_status "When you're done testing, clean up resources with:"
echo -e "${YELLOW}kubectl delete deployment inflate${NC}"
echo -e "${YELLOW}./cleanup.sh${NC}"

