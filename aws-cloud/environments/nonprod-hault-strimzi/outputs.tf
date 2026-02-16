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

output "database_master_password" {
  value     = random_password.db_password.result
  sensitive = true
}

output "bootstrap_brokers_sasl_scram" {
  value = module.kafka.bootstrap_brokers_sasl_scram
}

output "bootstrap_brokers_mtls" {
  value = module.kafka.bootstrap_brokers_mtls
}

output "ingress_class_name" {
  value = module.eks.ingress_class_name
}

output "cert_manager_selfsigned_cluster_issuer" {
  value = module.eks.cert_manager_selfsigned_cluster_issuer
}

output "hault_address" {
  value = module.secrets-manager.hault_address
}

output "hault_root_ca_tls_name" {
  value = module.secrets-manager.hault_root_ca_tls_name
}

output "dummy_saml_idp_basic_auth_user" {
  value = local.dummy_saml_idp_basic_auth_user
}

output "dummy_saml_idp_basic_auth_password" {
  value = local.dummy_saml_idp_basic_auth_password
}

output "kafka_init_sasl_scram_username" {
  value = local.kafka_init_sasl_scram_username
}

output "kafka_init_sasl_scram_password" {
  value = local.kafka_init_sasl_scram_password
}
