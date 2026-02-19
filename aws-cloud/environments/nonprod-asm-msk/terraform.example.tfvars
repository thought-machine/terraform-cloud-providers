# Prefix for resource names.
project                        = "PROJECT_NAME"
# Resource tag.
owner                          = "REPLACE_ME"
# AWS Region string.
aws_region                     = "REPLACE_ME"
# AWS CLI Profile name.
aws_profile                    = "REPLACE_ME"
# DNS domain name for resources.
project_domain                 = "REPLACE_ME"
# If using AWS Secrets Manager module, defines prefix paths for IAM roles, policies and secrets.
tm_iam_prefix                  = "tm/PROJECT_NAME"
# Prefix for secrets from a specific Vault Core instance.
secret_prefix                  = "tm-vault"
vault_installer_namespace      = "tm-system"
vault_installer_serviceaccount = "vault-installer"
# If using Strimzi Kafka module, must be either: "mtls" or "sasl-scram"
kafka_mode                     = "sasl-scram"
postgres_version               = "16.9"
kubernetes_version             = "1.35"
