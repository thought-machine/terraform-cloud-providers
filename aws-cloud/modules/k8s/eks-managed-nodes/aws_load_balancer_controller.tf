# https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html
# https://github.com/aws/eks-charts/tree/master/stable/aws-load-balancer-controller

module "aws_load_balancer_controller_irsa_role" {
  source                                 = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version                                = "6.4.0"
  name                                   = "aws-load-balancer-controller"
  attach_load_balancer_controller_policy = true
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  depends_on = [
    null_resource.kubectl, module.aws_load_balancer_controller_irsa_role, helm_release.cert_manager
  ]
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.13.4"
  namespace  = "kube-system"
  set = [
    {
      name  = "clusterName"
      value = module.eks.cluster_name
    },
    {
      name  = "serviceAccount.create"
      value = true
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.aws_load_balancer_controller_irsa_role.arn
    },
    {
      name  = "vpcId"
      value = var.vpc_id
    }
  ]
}
