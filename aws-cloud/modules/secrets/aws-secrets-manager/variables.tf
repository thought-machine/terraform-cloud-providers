variable "aws_region" {
  type = string
}

variable "project" {
  type = string
}

variable "eks_oidc_provider_arn" {
  type = string
}

variable "database_hostname" {
  type = string
}

variable "database_password" {
  type = string
}

variable "vault_installer_namespace" {
  type    = string
  default = "tm-system"
}

variable "vault_installer_serviceaccount" {
  type    = string
  default = "vault-installer"
}

variable "tm_iam_prefix" {
  type = string
}

variable "secret_prefix" {
  type = string
}

variable "dummy_saml_idp_basic_auth_user" {
  type    = string
  default = "someuser"
}

variable "dummy_saml_idp_basic_auth_password" {
  type    = string
  default = "topsecret"
}

variable "dependency" {
  description = "Implicit module dependencies."
  type        = any
}
