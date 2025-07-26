# Data sources to read cluster information from parent Terraform state
data "terraform_remote_state" "cluster" {
  backend = "local"
  
  config = {
    path = "../terraform.tfstate"
  }
}

# Get the AMI alias version
data "external" "ami_alias_version" {
  program = ["bash", "${path.module}/../../common/get_ami_version.sh", data.terraform_remote_state.cluster.outputs.cluster_name]
}
