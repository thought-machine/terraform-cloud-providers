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
  eks_name                = "${var.project}-eks"
  eks_ami_release_version = data.aws_ssm_parameter.eks_ami_release_version.value
}

data "aws_eks_cluster" "eks" {
  depends_on = [module.eks]
  name       = module.eks.cluster_name
}

data "aws_ssm_parameter" "eks_ami_release_version" {
  name = "/aws/service/eks/optimized-ami/${var.kubernetes_version}/amazon-linux-2023/x86_64/standard/recommended/image_id"
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

  addons = {
    coredns    = {}
    kube-proxy = {}
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

  node_security_group_tags = {
    "karpenter.sh/discovery" = var.project
  }

  eks_managed_node_groups = {
    "${var.project}-ondemand" = {
      desired_size   = 3
      min_size       = 1
      max_size       = 10
      instance_types = ["m6a.2xlarge", "m5a.2xlarge", "m5.2xlarge", "c6a.2xlarge", "c5a.2xlarge", "c5.2xlarge"]
      capacity_type  = "ON_DEMAND"
      labels = {
        # Karpenter to run on nodes not managed by itself.
        "karpenter.sh/controller" = "true"
      }
      use_latest_ami_release_version = false
      eks_ami_release_version        = local.eks_ami_release_version
      metadata_options = {
        # Unblock IMDSv2 from pod, workaround for core-db-online-migrator calls ec2imds: GetRegion"
        http_put_response_hop_limit = 2
      }
      iam_role_use_name_prefix = false
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
  storage_provisioner    = "ebs.csi.aws.com"
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

resource "terraform_data" "wait_for_aws_load_balancer_controller" {
  depends_on = [helm_release.aws_load_balancer_controller]
  # Ensure the waiter re-runs if the Helm release version changes
  input = helm_release.aws_load_balancer_controller.metadata.version
  provisioner "local-exec" {
    command = <<EOF
      echo "Waiting for AWS Load Balancer Controller to be ready..."
      export KUBECONFIG=$(mktemp)
      aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
      kubectl wait --namespace kube-system \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/name=aws-load-balancer-controller \
        --timeout=180s
      rm -f "$KUBECONFIG"
    EOF
    environment = {
      CLUSTER_NAME = module.eks.cluster_name
      AWS_REGION = var.aws_region
    }
  }
}