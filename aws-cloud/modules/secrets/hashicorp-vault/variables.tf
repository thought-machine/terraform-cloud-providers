variable "project" {
  type = string
}

variable "project_domain" {
  type = string
}

variable "oidc_provider_arn" {
  description = "OIDC provider of the EKS cluster"
  type        = string
}

variable "ingress_class_name" {
  type    = string
  default = "ingress-nginx-private"
}

variable "db_cluster_resource_id" {
  description = "RDS DB Cluster DbClusterResourceId, optional to enable DB IAM mode."
  type        = string
  default     = null
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

variable "tm_iam_db_admin" {
  type    = string
  default = "tm_admin_iam"
}

variable "dependency" {
  description = "Implicit module dependencies."
  type        = any
}
