output "vpc_id" {
  value = module.network.vpc_id
}
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

output "public_subnets" {
  value = module.network.public_subnets
}

output "private_subnets" {
  value = module.network.private_subnets
}

output "database_name" {
  value = module.db.cluster_database_name
}

output "database_cluster_endpoint" {
  value = module.db.cluster_endpoint
}

output "database_master_username" {
  value = module.db.master_username
}

output "vault_installer_role_arn" {
  value = module.secrets-manager.vault_installer_role_arn
}

output "msk_sasl_scram_cmk_arn" {
  value = module.kafka.msk_sasl_scram_cmk_arn
}

output "msk_cluster_arn" {
  value = module.kafka.msk_cluster_arn
}

output "bootstrap_brokers_sasl_scram" {
  value = module.kafka.bootstrap_brokers_sasl_scram
}

output "sm_role_permissions_boundary_arn" {
  value = module.secrets-manager.role_permissions_boundary_arn
}

output "ingress_class_name" {
  value = module.eks.ingress_class_name
}

output "cert_manager_selfsigned_cluster_issuer" {
  value = module.eks.cert_manager_selfsigned_cluster_issuer
}

output "dummy_saml_idp_basic_auth_user" {
  value = module.secrets-manager.dummy_saml_idp_basic_auth_user
}

output "dummy_saml_idp_basic_auth_password" {
  value = module.secrets-manager.dummy_saml_idp_basic_auth_password
}
