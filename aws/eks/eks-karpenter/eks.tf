// Instead of passing the AWS Region as parameter, we infer it from the provider configuration
data "aws_region" "current" {}

data "aws_availability_zones" "available" {}

data "aws_eks_cluster" "cluster" {
  name = module.eks_cluster.cluster_name
  depends_on = [module.eks_cluster.cluster_name]
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks_cluster.cluster_name
  depends_on = [module.eks_cluster.cluster_name]
}

module "eks_cluster" {
  source  = "terraform-aws-modules/eks/aws"
  # Latest version can be found at https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
  version = "19.16.0"
  
  # Name your EKS cluster in whatever name you would like
  cluster_name    = "opsbridge-cluster"
  # Kubernetes latest version can be found at https://kubernetes.io/releases/
  cluster_version = "1.27"

  # If you want that cluster plane API would be reachable from public address rather than private - enable this
  cluster_endpoint_public_access  = true

  # A list of the desired control plane logs to enable. https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Change with the VPC ID into which EKS control plane with nodes will be provisioned
  vpc_id                   = "<vpc-id>"
  # subnet_ids - A list of subnet IDs where the nodes/node groups will be provisioned.
  subnet_ids               = ["<subnet-id>", "<subnet-id>", "<subnet-id>"]
  # control_plane_subnet_ids - Is a list of subnet IDs where the EKS cluster control plane (ENIs) will be provisioned.
  # If control_plane_subnet_ids is not provided, the EKS cluster control plane (ENIs) will be provisioned in subnet_ids provided subnets.
  # control_plane_subnet_ids = ["<subnet-id>", "<subnet-id>", "<subnet-id>"]

  # aws-auth manages a configmap which maps IAM users and roles
  manage_aws_auth_configmap = "true"
  # Enable creation aws-auth configmap. Only if you are using self-managed node groups
  create_aws_auth_configmap = "false"

  # List of role maps to add to the aws-auth configmap
  aws_auth_roles = var.map_roles
  # List of user maps to add to the aws-auth configmap
  aws_auth_users = var.map_users

  # Enabling encryption on AWS EKS secrets using a customer-created key
  cluster_encryption_config = {
      provider_key_arn = aws_kms_key.eks_kms_key.arn
      resources        = ["secrets"]
  }

  # Additional EKS provided addons https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html
  cluster_addons = {
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }

  # IRSA enabled to create an OpenID trust between our cluster and IAM, in order to map AWS Roles to Kubernetes SA's
  enable_irsa = true

  # Configuration of nodes that will be provisioned. They will always exist even if
  # karpenter autoscalling will be configured.
  eks_managed_node_groups = {
    initial = {
      instance_types = ["t3.large"]

      min_size     = 1
      max_size     = 2
      desired_size = 1
    }
  }

  node_security_group_additional_rules = {

    node_to_node_ig = {
      description = "Node to node ingress traffic"
      from_port   = 1
      to_port     = 65535
      protocol    = "all"
      type        = "ingress"
      self        = true
    }

  }


  # With this tag - karpenter will detect which security group to use for autoscaled nodes
  node_security_group_tags = {
    "karpenter.sh/discovery" = "opsbridge-cluster"
  }

}