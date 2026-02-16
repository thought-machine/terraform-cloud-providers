# https://kubernetes.github.io/ingress-nginx/deploy/
locals {
  ingress_nginx_ingress_class = "nginx-kafka"
}

resource "helm_release" "kafka_nginx_ingress_controller" {
  depends_on       = [kubectl_manifest.kafka_broker_cert]
  name             = local.ingress_nginx_ingress_class
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = local.kafka_namespace
  create_namespace = true
  version          = "4.13.2"
  # https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/values.yaml
  set = [
    {
      name  = "controller.service.type"
      value = "LoadBalancer"
    },
    {
      # https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.7/guide/service/annotations/#traffic-routing
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
      value = "external"
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
      # Enable ssl passthrough for strimzi kafka
      name  = "controller.extraArgs.enable-ssl-passthrough"
      value = "true"
    },
  ]
}
