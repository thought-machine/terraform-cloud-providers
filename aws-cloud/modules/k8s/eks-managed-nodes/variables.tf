variable "project" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "route53_private_zone_arn" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.35"
}

variable "tm_iam_prefix" {
  type = string
}