output "root_db_secret_arn" {
  value = aws_secretsmanager_secret.root_db_secret.arn
}

output "vault_installer_role_arn" {
  value = module.irsa_vault_installer.arn
}

output "role_permissions_boundary_arn" {
  value = aws_iam_policy.application_permission_boundary.arn
}

output "dummy_saml_idp_basic_auth_user" {
  value = var.dummy_saml_idp_basic_auth_user
}

output "dummy_saml_idp_basic_auth_password" {
  value = var.dummy_saml_idp_basic_auth_password
}
