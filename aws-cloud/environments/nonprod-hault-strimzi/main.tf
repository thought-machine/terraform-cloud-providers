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

locals {
  kafka_init_sasl_scram_username     = "vault-kafka-init"
  kafka_init_sasl_scram_password     = "password"
  dummy_saml_idp_basic_auth_user     = "someuser"
  dummy_saml_idp_basic_auth_password = "topsecret"
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
  vpc_cidr       = var.vpc_cidr
}

module "eks" {
  source                   = "../../modules/k8s/eks-managed-nodes"
  project                  = var.project
  aws_region               = var.aws_region
  vpc_id                   = module.network.vpc_id
  private_subnet_ids       = module.network.private_subnets
  route53_private_zone_arn = module.network.aws_route53_private_zone_arn
  kubernetes_version       = var.kubernetes_version
  tm_iam_prefix            = var.tm_iam_prefix
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
  source             = "../../modules/secrets/hashicorp-vault"
  project            = var.project
  project_domain     = var.project_domain
  oidc_provider_arn  = module.eks.oidc_provider_arn
  ingress_class_name = module.eks.ingress_class_name
  db_cluster_resource_id         = var.iam_db_auth ? module.db.cluster_resource_id : null
  vault_installer_namespace      = var.vault_installer_namespace
  vault_installer_serviceaccount = var.vault_installer_serviceaccount
  tm_iam_prefix                  = var.tm_iam_prefix
  iam_db_auth        = var.iam_db_auth
  tm_db_admin        = var.tm_db_admin
  dependency         = module.eks.is_ready
}

module "kafka" {
  source                         = "../../modules/kafka/strimzi"
  project                        = var.project
  project_domain                 = var.project_domain
  kafka_init_sasl_scram_username = local.kafka_init_sasl_scram_username
  kafka_init_sasl_scram_password = local.kafka_init_sasl_scram_password
  dependency                     = module.eks.is_ready
  kafka_mode                     = var.kafka_mode
  kafka_version                  = "3.9.0"
}
