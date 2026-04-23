data "aws_caller_identity" "main" {}

locals {
  db_secrets_name = "root-db-secrets"
  db_secrets_value = {
    "${var.database_hostname}" = var.database_password
  }
  dummy_saml_idp_secrets_name = "dummy-saml-idp-secrets"
  dummy_saml_idp_secrets_value = {
    default = {
      basic_auth_user     = var.dummy_saml_idp_basic_auth_user
      basic_auth_password = var.dummy_saml_idp_basic_auth_password
    }
  }
  aws_account_id = data.aws_caller_identity.main.account_id
  dependency     = jsonencode(var.dependency)
}

resource "helm_release" "secrets_provider_aws" {
  depends_on = [local.dependency]
  name       = "secrets-provider-aws"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  namespace  = "kube-system"
  version    = "2.0.0"
}

resource "aws_secretsmanager_secret" "root_db_secret" {
  name                    = "${var.tm_iam_prefix}/${var.secret_prefix}/${local.db_secrets_name}"
  description             = "TM database root credentials for ${var.database_hostname}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "root_db_secret" {
  secret_id     = aws_secretsmanager_secret.root_db_secret.id
  secret_string = jsonencode(local.db_secrets_value)
}

# dummy idp password
resource "aws_secretsmanager_secret" "dummy_saml_idp" {
  name                    = "${var.tm_iam_prefix}/${var.secret_prefix}/${local.dummy_saml_idp_secrets_name}"
  description             = "For SAML authentication. The values must match common.basic_auth.password and common.basic_auth.username in the prepared values.yaml"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "dummy_saml_idp" {
  secret_id     = aws_secretsmanager_secret.dummy_saml_idp.id
  secret_string = jsonencode(local.dummy_saml_idp_secrets_value)
}

module "irsa_vault_installer" {
  depends_on = [local.dependency]
  source     = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version    = "6.2.1"
  name       = "${var.project}-vault-installer"
  path       = "/${var.tm_iam_prefix}/"
  policies = {
    "min_access" = aws_iam_policy.vault_installer_policy.arn
  }
  permissions_boundary = aws_iam_policy.vault_installer_policy.arn
  oidc_providers = {
    main = {
      provider_arn               = var.eks_oidc_provider_arn
      namespace_service_accounts = ["${var.vault_installer_namespace}:${var.vault_installer_serviceaccount}"]
    }
  }
}

# permissions boundary for the Vault Installer. vault-installer-policy.json
resource "aws_iam_policy" "vault_installer_policy" {
  name   = "${var.project}-vault-installer-policy"
  policy = data.aws_iam_policy_document.vault_installer_policy.json
}

data "aws_iam_policy_document" "vault_installer_policy" {
  statement {
    sid    = "AllowRolesOnlyInPath"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
    ]
    resources = [
      "arn:aws:iam::${local.aws_account_id}:role/${var.tm_iam_prefix}/*"
    ]
  }
  statement {
    sid    = "AllowSecretsOnlyInPath"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:CreateSecret",
      "secretsmanager:DescribeSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:UpdateSecret",
      "secretsmanager:PutSecretValue",
    ]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${local.aws_account_id}:secret:${var.tm_iam_prefix}/*",
    ]
  }
}

data "aws_iam_policy_document" "application_permission_boundary" {
  statement {
    sid    = "AllowGetSecretsOnlyInPath"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${local.aws_account_id}:secret:${var.tm_iam_prefix}/*",
    ]
  }
}

# vault-role-permission-boundary / application permission boundary
resource "aws_iam_policy" "application_permission_boundary" {
  name        = "${var.project}-vault-role-permission-boundary"
  description = "TM Vault applications permissions to AWS Secret Manager"
  policy      = data.aws_iam_policy_document.application_permission_boundary.json
}
