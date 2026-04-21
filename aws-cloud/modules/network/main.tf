locals {
  vpc_name = "${var.project}-vpc"
  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.main.names, 0, 3)
  endpoint_services = [
    "eks", "ecr.api", "ecr.dkr", "ec2", "sts"
  ]
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
  enable_nat_gateway = false
  single_nat_gateway = true # single shared private route table
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "karpenter.sh/discovery"          = var.project
  }
  default_security_group_ingress = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "Allow HTTPS from VPC CIDR"
      cidr_blocks = local.vpc_cidr
    }
  ]
}

resource "aws_route53_zone" "main" {
  name          = var.project_domain
  force_destroy = true
  vpc {
    vpc_id     = module.vpc.vpc_id
    vpc_region = var.aws_region
  }
}

# AWS Interface Endpoints for private subnets
resource "aws_vpc_endpoint" "interface" {
  for_each            = toset(local.endpoint_services)
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  private_dns_enabled = true
  tags = {
    Name    = "${var.project}-${each.value}"
  }
}

# S3 Gateway Endpoint for private subnets
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids
  tags = {
    Name    = "${var.project}-s3"
  }
}
