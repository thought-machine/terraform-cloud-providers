output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_arn" {
  value = module.eks.cluster_arn
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "oidc_provider" {
  value = module.eks.oidc_provider
}

output "oidc_issuer_url" {
  value = module.eks.cluster_oidc_issuer_url
}

output "ingress_class_name" {
  value = local.ingress_nginx_ingress_class
}

output "node_security_group_id" {
  value = module.eks.node_security_group_id
}

output "node_iam_role_arn" {
  value = module.eks.node_iam_role_arn
}

output "cert_manager_selfsigned_cluster_issuer" {
  value = local.cert_manager_selfsigned_cluster_issuer
}

output "is_ready" {
  description = "A synchronization point that completes only after CRDs and the LB Controller are fully ready."
  value = {
    crds          = null_resource.wait_for_crds.id
    lb_controller = terraform_data.wait_for_aws_load_balancer_controller.id
    metrics       = resource.helm_release.metrics_server.id
    priorityClass = resource.kubernetes_priority_class.platform_support.id
  }
}
