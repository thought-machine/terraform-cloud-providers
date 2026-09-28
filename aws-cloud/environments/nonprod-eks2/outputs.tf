output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_node_security_group_id" {
  value = module.eks.node_security_group_id
}

output "eks_oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "eks_oidc_provider" {
  value = module.eks.oidc_provider
}

output "ingress_class_name" {
  value = module.eks.ingress_class_name
}

output "cert_manager_selfsigned_cluster_issuer" {
  value = module.eks.cert_manager_selfsigned_cluster_issuer
}
