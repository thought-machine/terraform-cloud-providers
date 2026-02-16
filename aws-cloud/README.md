# AWS Cloud Platform for Thought Machine Vault Core

Terraform templates to provision AWS Cloud infrastructure prerequisites necessary for deployment of the Thought Machine Vault Core banking platform.

## Architecture Overview

Environments are configured in the [environments](./environments) directory. Currently, a nonprod environment is provided.

Each environment depends on a selection of supporting component Terraform modules in the [modules](./modules) directory.

The project structure is based on guidelines in [Terraform Best Practices for Large-size infrastructure with Terraform](https://www.terraform-best-practices.com/examples/terraform/large-size-infrastructure-with-terraform)

## Project Structure

```
aws-cloud/
├── environments/                   # Sample environment configuration variants
│   ├── nonprod-asm-msk/            #   Environment with AWS Secrets Manager, MSK Kafka
│   ├── nonprod-hault-strimzi/      #   Environment with Hashicorp Vault, Strimzi Kafka
├── modules/                        # Reusable Terraform modules
│   ├──db/                          #   Modules for databases
│   ├──k8s/                         #   Modules for Kubernetes clusters
│   ├──kafka/                       #   Modules for Kafka clusters
│   ├──network/                     #   Module for networking
│   ├──secrets/                     #   Modules for secrets management
└── README.md                       # This file
```

## Features

### Database

* Amazon Aurora Serverless for PostgreSQL instance.

### Kubernetes Cluster

* Amazon EKS cluster. EKS managed node group. Add-ons for: cert-manager, ingress-nginx, AWS LB controller, EBS CSI, VPC CNI, Metrics Server, external-dns

### Kafka Cluster

Choice of:
* Amazon MSK cluster with 3 brokers.
* Strimzi Kafka on EKS with 3 brokers.

### Network

* VPC network. Subnets across 3 Availability Zones, and DNS Route53 private zone.

### Secrets

Choice of:
* AWS Secrets Manager, creates a database root secret, and installs secrets-store CSI driver helm chart.
* Hashicorp Vault ("Hault") on EKS in HA mode with KMS auto unseal, and root token stored in k8s secret.

## Quick Start

### Prerequisites

* Workstation
  * Tested on: Linux host, Bash shell
  * aws cli v2
  * kubectl
  * terraform >= 1.0
* AWS Account
  * IAM principal with sufficient permissions

### Configure

Configure the environment in `terraform.tfvars` [example](./environments/nonprod-asm-msk/terraform.tfvars.example) in the selected [environments](./environments)/ENV_NAME subdirectory.

Configure the Terraform state S3 bucket in `backend.tfvars` [example](./environments/nonprod-asm-msk/backend.tfvars.example).

### Create Environment

```sh
terraform init -upgrade -backend-config=backend.tfvars
terraform plan
terraform apply
```

### Install Thought Machine Vault Core

Please refer to Thought Machine Vault Core documentation.

### Destroy Environment

To deprovision an environment.

```sh
terraform destroy
```
