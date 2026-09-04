# https://kubernetes.github.io/ingress-nginx/deploy/
locals {
  ingress_nginx_ingress_class = "ingress-nginx-private"
}

resource "helm_release" "ingress_nginx" {
  depends_on       = [null_resource.kubectl]
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.13.2"
  # https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/values.yaml
  set = [
    {
      name  = "controller.service.type"
      value = "LoadBalancer"
    },
    {
      name  = "controller.service.loadBalancerClass"
      value = "eks.amazonaws.com/nlb"
    },
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-nlb-target-type"
      value = "ip"
    },
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
      value = "internal"
    },
    {
      # To allow ingress controller to see clients source IPs in order to do IP whitelisting
      name  = "controller.service.externalTrafficPolicy"
      value = "Local"
    },
    {
      name  = "controller.ingressClass"
      value = local.ingress_nginx_ingress_class
    },
    {
      name  = "controller.ingressClassResource.controllerValue"
      value = "k8s.io/${local.ingress_nginx_ingress_class}"
    },
    {
      name  = "controller.ingressClassResource.name"
      value = local.ingress_nginx_ingress_class
    },
    {
      # Process Ingress objects without ingressClass annotation/ingressClassName field Overrides value for --watch-ingress-without-class flag of the controller binary
      name  = "controller.watchIngressWithoutClass"
      value = "false"
    },
    {
      # We enable ssl passthrough for strimzi kafka
      name  = "controller.extraArgs.enable-ssl-passthrough"
      value = "true"
    },
  ]
}
