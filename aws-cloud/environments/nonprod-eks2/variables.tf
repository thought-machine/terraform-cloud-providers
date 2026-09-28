variable "project" {
  description = "Project name for this EKS cluster"
  type        = string
}

variable "vpc_name" {
  description = "VPC name, existing"
  type        = string
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

variable "project_domain" {
  type = string
}

variable "tm_iam_prefix" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.35"
}
