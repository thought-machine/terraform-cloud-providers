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

variable "dependency" {
  description = "Implicit module dependencies."
  type        = any
}
