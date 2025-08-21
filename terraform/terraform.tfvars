cluster_name = "test-cluster"

# Existing VPC Configuration
create_vpc = false
vpc_id = "vpc-0c75749c9b52a0055"  # Replace with your actual VPC ID

# EKS Endpoint Access Configuration - Private only for security
cluster_endpoint_public_access = true
cluster_endpoint_private_access = true
cluster_endpoint_public_access_cidrs = ["1.2.3.4/32"]
