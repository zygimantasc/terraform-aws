# Examples that were used were https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/examples/karpenter/main.tf

# This module creates needed IAM resources for Karpenter resources to use which are deployed with helm charts
module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"

  cluster_name = module.eks_cluster.cluster_name

  irsa_oidc_provider_arn          = module.eks_cluster.oidc_provider_arn
  irsa_namespace_service_accounts = ["karpenter:karpenter"]

  create_iam_role = false
  iam_role_arn    = module.eks_cluster.eks_managed_node_groups["initial"].iam_role_arn

  policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

# Authentication can only be made from us-east-1 ECR API, so using different provider, this is a bug
# https://github.com/aws/karpenter/issues/3015
provider "aws" {
  region = "us-east-1"
  alias = "virginia"
}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

resource "helm_release" "karpenter" {
  depends_on       = [module.eks_cluster.kubeconfig]
  namespace        = "karpenter"
  create_namespace = true

  # https://artifacthub.io/packages/helm/karpenter/karpenter Was not working, so
  # https://github.com/aws/karpenter/tree/main/charts/karpenter chart was used
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "v0.21.1"
  
  # Make sure that the service account uses IRSA role with OIDC trust-relationships
  set {
    name  = "settings.aws.clusterName"
    value = module.eks_cluster.cluster_name
  }

  set {
    name  = "settings.aws.clusterEndpoint"
    value = module.eks_cluster.cluster_endpoint
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter.irsa_arn
  }

  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = module.karpenter.instance_profile_name
  }

  set {
    name  = "settings.aws.interruptionQueueName"
    value = module.karpenter.queue_name
  }
}

## Creating a provisioner which will create nodes for unscheduled pods
resource "kubernetes_manifest" "karpenter_provisioner" {
  # Terraform by default doesn't tolerate values changing between configuration and apply results.
  # Users are required to declare these tolerable exceptions explicitly.
  # With a kubernetes_manifest resource, you can achieve this by using the computed_fields meta-attribute.
  computed_fields = ["spec.requirements", "spec.limits"]
  manifest = yamldecode(<<-EOF
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: default
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
        - key: "karpenter.k8s.aws/instance-category"
          operator: In
          values: ["t"]
        - key: "karpenter.k8s.aws/instance-cpu"
          operator: In
          values: ["2"]
        - key: "karpenter.k8s.aws/instance-generation"
          operator: In
          values: ["3"]
      limits:
        resources:
          cpu: 1000
      providerRef:
        name: default
      ttlSecondsAfterEmpty: 30
  EOF
  )

  depends_on = [
    helm_release.karpenter
  ]
}

# Creating a Node template, which will be used for Node configuration in AWS side
resource "kubernetes_manifest" "karpenter_node_template" {
  # Terraform by default doesn't tolerate values changing between configuration and apply results.
  # Users are required to declare these tolerable exceptions explicitly.
  # With a kubernetes_manifest resource, you can achieve this by using the computed_fields meta-attribute.
  computed_fields = ["spec.requirements", "spec.limits"]
  manifest = yamldecode(<<-EOF
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: default
    spec:
      subnetSelector:
        karpenter.sh/discovery: ${module.eks_cluster.cluster_name}
      securityGroupSelector:
        karpenter.sh/discovery: ${module.eks_cluster.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks_cluster.cluster_name}
  EOF
  )

  depends_on = [
    helm_release.karpenter
  ]
}

# Test deployment using the [pause image](https://www.ianlewis.org/en/almighty-pause-container)
# If you want to inflate - use kubectl scale --replicas=20 deployment/inflate
resource "kubernetes_manifest" "karpenter_example_deployment" {
  manifest = yamldecode(<<-EOF
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      namespace: default
      name: inflate
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: inflate
      template:
        metadata:
          labels:
            app: inflate
        spec:
          terminationGracePeriodSeconds: 0
          containers:
            - name: inflate
              image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
              resources:
                requests:
                  cpu: 500m
  EOF
  )

  depends_on = [
    helm_release.karpenter
  ]
}
