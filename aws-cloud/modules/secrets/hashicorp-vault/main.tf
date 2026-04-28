terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
  }
}

locals {
  hault_name               = "hault"
  hault_namespace          = "hault-system"
  hault_hostname           = "${local.hault_name}.${var.project_domain}"
  hault_address            = "https://${local.hault_hostname}:443"
  hault_tls_cert_name      = "hault-tls-cert"
  hault_root_tls_cert_name = "hault-root-ca-tls"
  root_token_secret_name   = "hault-init"
  aws_account_id           = data.aws_caller_identity.main.account_id
  dependency               = jsonencode(var.dependency)
}

data "aws_caller_identity" "main" {}

data "aws_region" "current" {}

#### Hashicorp Vault ####
# https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-raft-deployment-guide
# https://developer.hashicorp.com/vault/tutorials/auto-unseal/autounseal-aws-kms
resource "helm_release" "hault_chart" {
  depends_on       = [local.dependency, terraform_data.pvc_cleanup]
  name             = "hault"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  version          = "0.31.0"
  namespace        = local.hault_namespace
  create_namespace = true
  values = [<<EOT
global:
  enabled: true
  tlsDisable: false
  resources:
    requests:
      memory: 256Mi
      cpu: 250m
    limits:
      memory: 256Mi
      cpu: 250m

server:

  serviceAccount:
    create: true
    # name: hault-vault
    # createSecret: true # non-expiring token for the service account.
    annotations:
      eks.amazonaws.com/role-arn: "${module.hault_role.arn}"

  ingress:
    enabled: true
    annotations:
        external-dns.alpha.kubernetes.io/hostname: ${local.hault_hostname}
        kubernetes.io/ingress.class: ${var.ingress_class_name}
        nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
        nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
        nginx.ingress.kubernetes.io/proxy-ssl-verify: "off"
        nginx.ingress.kubernetes.io/proxy-body-size: "0"
    ingressClassName: ${var.ingress_class_name}
    hosts:
      - host: ${local.hault_hostname}
        paths: []
    tls:
      - secretName: ${local.hault_tls_cert_name}
        hosts:
          - ${local.hault_hostname}

  # These Resource Limits are in line with node requirements in the
  # Vault Reference Architecture for a Small Cluster
  resources:
    requests:
      memory: 8Gi
      cpu: 2000m
    limits:
      memory: 16Gi
      cpu: 2000m

  # For HA configuration and because we need to manually init the vault,
  # we need to define custom readiness/liveness Probe settings
  readinessProbe:
    enabled: true
    path: "/v1/sys/health?standbyok=true&sealedcode=204&uninitcode=204"
  livenessProbe:
    enabled: true
    path: "/v1/sys/health?standbyok=true"
    initialDelaySeconds: 60

  # extraEnvironmentVars is a list of extra environment variables to set with the stateful set. These could be
  # used to include variables required for auto-unseal.
  extraEnvironmentVars:
    VAULT_CACERT: /vault/userconfig/${local.hault_tls_cert_name}/ca.crt

  # extraVolumes is a list of extra volumes to mount. These will be exposed
  # to Vault in the path `/vault/userconfig/<name>/`.
  extraVolumes:
    - type: secret
      name: ${local.hault_tls_cert_name}

  persistentVolumeClaimRetentionPolicy:
    whenDeleted: Delete
    whenScaled: Delete

  standalone:
    enabled: false

  # Run Vault in "HA" mode.
  ha:
    enabled: true
    replicas: 3
    raft:
      enabled: true
      setNodeId: true

      config: |
        ui = true
        cluster_name = "vault-integrated-storage"
        listener "tcp" {
          address = "0.0.0.0:8200"
          cluster_address = "0.0.0.0:8201"
          tls_cert_file = "/vault/userconfig/${local.hault_tls_cert_name}/tls.crt"
          tls_key_file = "/vault/userconfig/${local.hault_tls_cert_name}/tls.key"
        }
        service_registration "kubernetes" {}

        storage "raft" {
          path = "/vault/data"
          retry_join {
            leader_api_addr = "https://hault-vault-0.hault-vault-internal:8200"
            leader_ca_cert_file = "/vault/userconfig/${local.hault_tls_cert_name}/ca.crt"
            leader_client_cert_file = "/vault/userconfig/${local.hault_tls_cert_name}/tls.crt"
            leader_client_key_file = "/vault/userconfig/${local.hault_tls_cert_name}/tls.key"
          }
          retry_join {
            leader_api_addr = "https://hault-vault-1.hault-vault-internal:8200"
            leader_ca_cert_file = "/vault/userconfig/${local.hault_tls_cert_name}/ca.crt"
            leader_client_cert_file = "/vault/userconfig/${local.hault_tls_cert_name}/tls.crt"
            leader_client_key_file = "/vault/userconfig/${local.hault_tls_cert_name}/tls.key"
          }
          retry_join {
            leader_api_addr = "https://hault-vault-2.hault-vault-internal:8200"
            leader_ca_cert_file = "/vault/userconfig/${local.hault_tls_cert_name}/ca.crt"
            leader_client_cert_file = "/vault/userconfig/${local.hault_tls_cert_name}/tls.crt"
            leader_client_key_file = "/vault/userconfig/${local.hault_tls_cert_name}/tls.key"
          }
        }
        seal "awskms" {
          region     = "${data.aws_region.current.region}"
          kms_key_id = "${aws_kms_key.hault.key_id}"
        }

  priorityClassName: "platform-support"

EOT
  ]
}

resource "terraform_data" "pvc_cleanup" {
  input = {
    namespace = local.hault_namespace
  }
  provisioner "local-exec" {
    when    = destroy
    command = "timeout 60s kubectl delete pvc -l app.kubernetes.io/name=vault -n ${self.input.namespace} --grace-period=0 --force --ignore-not-found | true"
  }
}

#### Certificate ####

resource "kubectl_manifest" "hault_root_ca_issuer" {
  depends_on = [helm_release.hault_chart]
  yaml_body  = <<-EOF
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: hault-root-ca-issuer
  namespace: ${local.hault_namespace}
spec:
  selfSigned: {}
EOF
}

resource "kubectl_manifest" "hault_root_ca_certificate" {
  depends_on = [kubectl_manifest.hault_root_ca_issuer]
  yaml_body  = <<-EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: hault-root-ca-certificate
  namespace: ${local.hault_namespace}
spec:
  isCA: true
  commonName: Hault Self-Signed Root CA
  secretName: ${local.hault_root_tls_cert_name} # <-- will contain ca.crt + tls.crt + tls.key
  issuerRef:
    name: hault-root-ca-issuer
    kind: Issuer
EOF
}

resource "kubectl_manifest" "hault_ca_issuer" {
  depends_on = [kubectl_manifest.hault_root_ca_certificate]
  yaml_body  = <<-EOF
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: hault-ca-issuer
  namespace: ${local.hault_namespace}
spec:
  ca:
    secretName: ${local.hault_root_tls_cert_name}
EOF
}

resource "kubectl_manifest" "hault_tls_cert" {
  depends_on = [kubectl_manifest.hault_ca_issuer]
  yaml_body  = <<-EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${local.hault_tls_cert_name}
  namespace: ${local.hault_namespace}
spec:
  secretName: ${local.hault_tls_cert_name}
  issuerRef:
    name: hault-ca-issuer
    kind: Issuer
  duration: 2160h
  renewBefore: 360h
  subject:
    organizationalUnits:
      - "hault"
    organizations:
      - "Thought Machine Ltd"
  dnsNames:
    - "${local.hault_hostname}"
    - "hault-vault.svc.cluster.local"
    - "hault-vault-internal.svc.cluster.local"
    - "hault.svc.cluster.local"
    - "*.hault.svc.cluster.local"
    - "*.hault-vault-internal"
EOF
}


#### Unseal ####

resource "random_pet" "env" {
  length    = 2
  separator = "_"
}

resource "aws_kms_alias" "hault" {
  name          = "alias/hault-kms-unseal-${random_pet.env.id}"
  target_key_id = aws_kms_key.hault.key_id
}

resource "aws_kms_key" "hault" {
  description             = "Hault unseal key"
  deletion_window_in_days = 7
  tags = {
    Name = "hault-kms-unseal-${random_pet.env.id}"
  }
  # bypass_policy_lockout_safety_check to workaround MalformedPolicyDocumentException:
  #   The new key policy will not allow you to update the key policy in the future.
  bypass_policy_lockout_safety_check = true # Use with Caution.
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Id" : "key-default-1",
    "Statement" : [
      {
        "Sid" : "Enable IAM User Permissions",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : ["*"]
        },
        "Action" : "kms:*",
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_policy" "hault_kms" {
  name        = "${var.project}-VaultKMSUnsealPolicy"
  path        = "/${var.tm_iam_prefix}/"
  description = "Allows Hault to use KMS for unsealing"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["kms:Encrypt", "kms:Decrypt", "kms:DescribeKey"]
      Resource = "${aws_kms_key.hault.arn}"
    }]
  })
}

module "hault_role" {
  source                = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version               = "6.4.0"
  name                  = "${var.project}-hault-kms-unseal-role"
  path                  = "/${var.tm_iam_prefix}/"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true
  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["hault-system:hault-vault"]
    }
  }
  policies = {
    policy = aws_iam_policy.hault_kms.arn
  }
}

resource "terraform_data" "hault_init" {
  depends_on = [helm_release.hault_chart, aws_kms_key.hault, module.hault_role]
  input = {
    hault_namespace        = local.hault_namespace
    root_token_secret_name = local.root_token_secret_name
  }
  # Create-time
  provisioner "local-exec" {
    command = "sleep 10 && ${path.module}/hault_init.sh"
    environment = {
      HAULT_NAMESPACE        = self.input.hault_namespace
      HAULT_POD              = "hault-vault-0"
      ROOT_TOKEN_SECRET_NAME = self.input.root_token_secret_name
    }
  }
  # Destroy-time
  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete secret ${self.input.root_token_secret_name} -n ${self.input.hault_namespace} --ignore-not-found"
  }
}
