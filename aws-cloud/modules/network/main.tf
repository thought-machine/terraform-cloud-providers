locals {
  vpc_name = "${var.project}-vpc"
  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.main.names, 0, 3)
}

data "aws_availability_zones" "main" {
  state = "available"
}

module "vpc" {
  source             = "terraform-aws-modules/vpc/aws"
  version            = "6.2.0"
  name               = local.vpc_name
  cidr               = local.vpc_cidr
  azs                = local.azs
  public_subnets     = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  private_subnets    = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k + 3)]
  database_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k + 6)]
  enable_nat_gateway = true
  single_nat_gateway = true
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "karpenter.sh/discovery"          = var.project
  }
}

resource "aws_route53_zone" "main" {
  name          = var.project_domain
  force_destroy = true
  vpc {
    vpc_id     = module.vpc.vpc_id
    vpc_region = var.aws_region
  }
}