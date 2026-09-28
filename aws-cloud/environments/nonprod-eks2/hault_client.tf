locals {
  hault_tls_cert_name      = "hault-tls-cert"
  hault_root_tls_cert_name = "hault-root-ca-tls"
  root_token_secret_name   = "hault-init"
  aws_account_id           = data.aws_caller_identity.main.account_id
  eks_cluster_name         = "${var.project}-eks"
  dependency               = module.eks.is_ready
  vault_installer_serviceaccount = "vault-installer"
}

data "aws_caller_identity" "main" {}

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
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["tm-system:${local.vault_installer_serviceaccount}"]
    }
  }
}

# permissions boundary for the Vault Installer. vault-installer-policy.json
resource "aws_iam_policy" "vault_installer_policy" {
  name  = "${var.project}-vault-installer-policy"
  path  = "/${var.tm_iam_prefix}/"
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
}
