terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
  }
}

locals {
  eks_name = "${var.project}-eks"
}

data "aws_eks_cluster" "eks" {
  depends_on = [module.eks]
  name       = module.eks.cluster_name
}

resource "null_resource" "kubectl" {
  depends_on = [module.eks]
  provisioner "local-exec" {
    command = "aws eks --region ${var.aws_region} update-kubeconfig --name ${data.aws_eks_cluster.eks.name}"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.10.0"

  name               = local.eks_name
  kubernetes_version = var.kubernetes_version
  create_iam_role    = true

  endpoint_public_access       = true
  endpoint_private_access      = true
  vpc_id                       = var.vpc_id
  control_plane_subnet_ids     = var.private_subnet_ids
  endpoint_public_access_cidrs = ["0.0.0.0/0"]

  create_cloudwatch_log_group = false
  enabled_log_types           = []

  # Enable EKS Auto Mode (delegates node, storage, and load balancer lifecycle to AWS)
  compute_config = {
    enabled    = true
    node_pools = ["general-purpose", "system"]
  }

  # Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true

  subnet_ids = var.private_subnet_ids

  # Disable cluster secrets encryption, as workaround to avoid KMS error:
  #   MalformedPolicyDocumentException: "The new key policy will not allow you to update the key policy in the future."
  # To enable, do so outside of Terraform. https://docs.aws.amazon.com/eks/latest/userguide/enable-kms.html
  encryption_config = null
  create_kms_key    = false

  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node"
      protocol    = "-1" # All ports
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    ingress_control_plane = {
      description                   = "Control plane to nodes"
      protocol                      = "-1" # All ports
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }
}

resource "time_sleep" "wait_for_rbac" {
  depends_on      = [module.eks.access_entries]
  create_duration = "60s"
}

resource "kubernetes_storage_class" "gp3" {
  depends_on = [time_sleep.wait_for_rbac]
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner    = "ebs.csi.eks.amazonaws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"
  parameters = {
    "encrypted" = "true"
    "fsType"    = "ext4"
    "type"      = "gp3"
  }
}

resource "kubernetes_priority_class" "platform_support" {
  depends_on = [time_sleep.wait_for_rbac]
  metadata {
    name = "platform-support"
  }
  description = "For essential, supporting, prereq pods."
  value       = 50
}

resource "null_resource" "wait_for_crds" {
  depends_on = [helm_release.cert_manager]
  provisioner "local-exec" {
    command = <<EOF
      export KUBECONFIG=$(mktemp)
      aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
      for i in {1..30}; do
        kubectl get crd issuers.cert-manager.io && rm -f "$KUBECONFIG" && exit 0
        echo "Waiting for cert-manager CRDs..."
        sleep 10
      done
      rm -f "$KUBECONFIG" && exit 1
    EOF
    environment = {
      CLUSTER_NAME = module.eks.cluster_name
      AWS_REGION = var.aws_region
    }
  }
}
