terraform {
  required_version = "~> 1.14.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
  backend "s3" {
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
  default_tags {
    tags = {
      Owner      = var.owner
      Project    = var.project
      Created_by = "Terraform"
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    command     = "aws"
  }
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command     = "aws"
    }
  }
}

module "network" {
  source         = "../../modules/network"
  project        = var.project
  aws_region     = var.aws_region
  project_domain = var.project_domain
}

module "eks" {
  source                   = "../../modules/k8s/eks-managed-nodes"
  project                  = var.project
  aws_region               = var.aws_region
  vpc_id                   = module.network.vpc_id
  private_subnet_ids       = module.network.private_subnets
  route53_private_zone_arn = module.network.aws_route53_private_zone_arn
  kubernetes_version       = var.kubernetes_version
}

module "db" {
  source                     = "../../modules/db/aurora-serverless"
  project                    = var.project
  vpc_id                     = module.network.vpc_id
  database_subnet_group_name = module.network.database_subnet_group_name
  app_security_group_id      = module.eks.node_security_group_id
  postgres_version           = var.postgres_version
  master_username            = "postgres"
  master_password            = random_password.db_password.result
}

resource "random_password" "db_password" {
  length           = 8
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

module "secrets-manager" {
  source                         = "../../modules/secrets/aws-secrets-manager"
  project                        = var.project
  aws_region                     = var.aws_region
  eks_oidc_provider_arn          = module.eks.oidc_provider_arn
  database_hostname              = module.db.cluster_endpoint
  database_password              = random_password.db_password.result
  tm_iam_prefix                  = var.tm_iam_prefix
  secret_prefix                  = var.secret_prefix
  vault_installer_namespace      = var.vault_installer_namespace
  vault_installer_serviceaccount = var.vault_installer_serviceaccount
  dependency                     = module.eks.is_ready
}

module "kafka" {
  source                = "../../modules/kafka/aws-msk"
  project               = var.project
  private_subnet_ids    = module.network.private_subnets
  app_security_group_id = module.eks.node_security_group_id
  kafka_version         = "3.9.x"
}
