variable "project" {
  type = string
}

variable "owner" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "aws_profile" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "project_domain" {
  type = string
}

variable "tm_iam_prefix" {
  type = string
}

variable "secret_prefix" {
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

variable "kafka_mode" {
  type        = string
  description = "Currently unused in this enviroment."
}

variable "postgres_version" {
  type    = string
  default = "16.9"
}

variable "kubernetes_version" {
  type    = string
  default = "1.35"
}

variable "iam_db_auth" {
  description = "Toggles IAM RBAC auth for database, instead of password. Not supported for ASM MSK mode. Set to false."
  type    = bool
  default = false
}

variable "tm_db_admin" {
  description = "Database admin user. Not used in ASM MSK mode."
  type = string
  default = "tm_admin"
}
