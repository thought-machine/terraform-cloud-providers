output "hault_address" {
  value = local.hault_address
}

output "hault_root_ca_tls_name" {
  value = local.hault_root_tls_cert_name
}

output "vault_installer_role_arn" {
  value = one(module.irsa_vault_installer[*].arn)
}
