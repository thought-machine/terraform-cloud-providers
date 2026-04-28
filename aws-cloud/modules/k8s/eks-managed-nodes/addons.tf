module "vpc_cni_irsa" {
  source                = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version               = "6.4.0"
  name                  = "vpc-cni"
  path                  = "/${var.tm_iam_prefix}/"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "vpc-cni"
  service_account_role_arn = module.vpc_cni_irsa.arn
}

module "ebs_csi_irsa" {
  source                = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version               = "6.4.0"
  name                  = "ebs-csi"
  path                  = "/${var.tm_iam_prefix}/"
  attach_ebs_csi_policy = true
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node", "kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = "v1.54.0-eksbuild.1"
  service_account_role_arn    = module.ebs_csi_irsa.arn
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "helm_release" "metrics_server" {
  depends_on = [time_sleep.wait_for_rbac]
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
}

# https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/aws.md
resource "aws_eks_addon" "external_dns" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "external-dns"
  addon_version            = "v0.19.0-eksbuild.2"
  service_account_role_arn = module.external_dns_irsa.arn
}

module "external_dns_irsa" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version                       = "6.4.0"
  name                          = "external-dns"
  path                          = "/${var.tm_iam_prefix}/"
  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = [var.route53_private_zone_arn]
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-dns:external-dns"]
    }
  }
}
