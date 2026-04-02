terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
  }
}

locals {
  kafka_namespace         = "kafka"
  kafka_name              = "kafka-${var.project}"
  kafka_subdomain         = "${local.kafka_namespace}.${var.project_domain}"
  sasl_broker_hostnames   = formatlist("kafka-%s.${local.kafka_subdomain}", range(var.kafka_broker_replicas))
  mtls_broker_hostnames   = formatlist("mtls-%s.${local.kafka_subdomain}", range(var.kafka_broker_replicas))
  oauth_broker_hostnames  = formatlist("oauth-%s.${local.kafka_subdomain}", range(var.kafka_broker_replicas))
  sasl_bootstrap_hostname = "sasl-bootstrap.${local.kafka_subdomain}"
  mtls_bootstrap_hostname = "mtls-bootstrap.${local.kafka_subdomain}"
  oauth_bootstrap_hostname= "oauth-bootstrap.${local.kafka_subdomain}"
  kafka_broker_cert       = "kafka-broker-cert"
  sasl_external_port      = 9093
  mtls_external_port      = 9094
  oauth_external_port     = 9096
  kafka_init_username     = var.kafka_init_sasl_scram_username
  kafka_init_user_secret = {
    username = var.kafka_init_sasl_scram_username
    password = var.kafka_init_sasl_scram_password
  }
  kafka_init_user_base64_password = base64encode(local.kafka_init_user_secret.password)
  kafka_init_user_password_yaml   = <<-EOT
    password:
      valueFrom:
        secretKeyRef:
          name: ${local.kafka_init_username}
          key: password
  EOT
  ca_cert                         = data.kubernetes_secret.cert_manager_root_ca.data["ca.crt"]
  ca_key                          = data.kubernetes_secret.cert_manager_root_ca.data["tls.key"]
  strimzi_kafka_ssl_dir_path      = "/strimzi-kafka-certs"
  # implicit dependency
  dependency = jsonencode(var.dependency)
}

#### Strimzi Kafka ####
# https://strimzi.io/quickstarts/

resource "helm_release" "strimzi" {
  depends_on       = [local.dependency]
  name             = "strimzi-cluster-operator"
  repository       = "oci://quay.io/strimzi-helm/"
  chart            = "strimzi-kafka-operator"
  namespace        = local.kafka_namespace
  create_namespace = true
  version          = "0.45.1" # Strimzi 0.45 is the last minor Strimzi version with support for ZooKeeper
  set = [
    {
      name  = "replicas"
      value = 1
    },
    {
      name  = "watchAnyNamespace"
      value = true
    }
  ]
}

resource "kubectl_manifest" "kafka_nodepool" {
  depends_on = [helm_release.strimzi]
  yaml_body  = <<-EOF
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaNodePool
metadata:
  name: pool
  namespace: ${local.kafka_namespace}
  labels:
    strimzi.io/cluster: ${local.kafka_name}
spec:
  replicas: 3
  roles:
    - broker
  storage:
    type: persistent-claim
    size: 30Gi
    deleteClaim: true
    kraftMetadata: shared
EOF
}

resource "kubectl_manifest" "kafka_cluster" {
  depends_on = [
    kubectl_manifest.kafka_nodepool,
    kubectl_manifest.kafka_broker_cert
  ]
  yaml_body = <<-EOF
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: ${local.kafka_name}
  namespace: ${local.kafka_namespace}
  annotations:
    strimzi.io/node-pools: enabled
spec:
  kafka:
    version: ${var.kafka_version}
    replicas: ${var.kafka_broker_replicas}
    template:
      pod:
        priorityClassName: "platform-support"

    listeners:

      - name: plainint
        port: 9092
        type: internal
        tls: false

      - name: mtlsint
        port: 9095
        type: internal
        tls: true
        authentication:
          type: tls

      # External sasl-scram listener
      - name: scram
        port: ${local.sasl_external_port}
        type: ingress
        tls: true
        authentication:
          type: scram-sha-512
        authorization:
          type: simple
        configuration:
          class: ${local.ingress_nginx_ingress_class}
          bootstrap:
            host: ${local.sasl_bootstrap_hostname}
            alternativeNames:
            - kafka
            - ${local.kafka_name}-kafka-bootstrap.${local.kafka_namespace}.svc.cluster.local
            annotations:
              kubernetes.io/ingress.class: ${local.ingress_nginx_ingress_class}
              external-dns.alpha.kubernetes.io/hostname: ${local.sasl_bootstrap_hostname}
          brokers:
          - broker: 0
            host: ${local.sasl_broker_hostnames[0]}
            annotations:
              kubernetes.io/ingress.class: ${local.ingress_nginx_ingress_class}
              external-dns.alpha.kubernetes.io/hostname: ${local.sasl_broker_hostnames[0]}
          - broker: 1
            host: ${local.sasl_broker_hostnames[1]}
            annotations:
              kubernetes.io/ingress.class: ${local.ingress_nginx_ingress_class}
              external-dns.alpha.kubernetes.io/hostname: ${local.sasl_broker_hostnames[1]}
          - broker: 2
            host:  ${local.sasl_broker_hostnames[2]}
            annotations:
              kubernetes.io/ingress.class: ${local.ingress_nginx_ingress_class}
              external-dns.alpha.kubernetes.io/hostname: ${local.sasl_broker_hostnames[2]}
          brokerCertChainAndKey:
            secretName: ${local.kafka_broker_cert}
            certificate: tls.crt
            key: tls.key

      # External mTLS listener
      - name: mtls
        port: ${local.mtls_external_port}
        type: ingress
        tls: true
        authentication:
          type: tls
        authorization:
          type: tls
        configuration:
          class: ${local.ingress_nginx_ingress_class}
          bootstrap:
            host: ${local.mtls_bootstrap_hostname}
            alternativeNames:
            - mtls-bootstrap
            - mtls-bootstrap.${local.kafka_namespace}.svc.cluster.local
            annotations:
              kubernetes.io/ingress.class: ${local.ingress_nginx_ingress_class}
              external-dns.alpha.kubernetes.io/hostname: ${local.mtls_bootstrap_hostname}
          brokers:
          - broker: 0
            host: ${local.mtls_broker_hostnames[0]}
            annotations:
              kubernetes.io/ingress.class: ${local.ingress_nginx_ingress_class}
              external-dns.alpha.kubernetes.io/hostname: ${local.mtls_broker_hostnames[0]}
          - broker: 1
            host: ${local.mtls_broker_hostnames[1]}
            annotations:
              kubernetes.io/ingress.class: ${local.ingress_nginx_ingress_class}
              external-dns.alpha.kubernetes.io/hostname: ${local.mtls_broker_hostnames[1]}
          - broker: 2
            host:  ${local.mtls_broker_hostnames[2]}
            annotations:
              kubernetes.io/ingress.class: ${local.ingress_nginx_ingress_class}
              external-dns.alpha.kubernetes.io/hostname: ${local.mtls_broker_hostnames[2]}
          brokerCertChainAndKey:
            secretName: ${local.kafka_broker_cert}
            certificate: tls.crt
            key: tls.key

      # Extrernal OAuth listener
      - name: oauth
        port: ${local.oauth_external_port}
        type: ingress
        tls: true
        authentication:
          type: oauth
          validIssuerUri: ${var.oidc_issuer_url}
          jwksEndpointUri: ${var.oidc_issuer_url}/keys
          userNameClaim: sub
        authorization:
          type: simple
        configuration:
          class: ${local.ingress_nginx_ingress_class}
          bootstrap:
            host: ${local.oauth_bootstrap_hostname}
            alternativeNames:
            - oauth-bootstrap
            - oauth-bootstrap.${local.kafka_namespace}.svc.cluster.local
            annotations:
              kubernetes.io/ingress.class: ${local.ingress_nginx_ingress_class}
              external-dns.alpha.kubernetes.io/hostname: ${local.oauth_bootstrap_hostname}
          brokers:
          - broker: 0
            host: ${local.oauth_broker_hostnames[0]}
            annotations:
              kubernetes.io/ingress.class: ${local.ingress_nginx_ingress_class}
              external-dns.alpha.kubernetes.io/hostname: ${local.oauth_broker_hostnames[0]}
          - broker: 1
            host: ${local.oauth_broker_hostnames[1]}
            annotations:
              kubernetes.io/ingress.class: ${local.ingress_nginx_ingress_class}
              external-dns.alpha.kubernetes.io/hostname: ${local.oauth_broker_hostnames[1]}
          - broker: 2
            host:  ${local.oauth_broker_hostnames[2]}
            annotations:
              kubernetes.io/ingress.class: ${local.ingress_nginx_ingress_class}
              external-dns.alpha.kubernetes.io/hostname: ${local.oauth_broker_hostnames[2]}
          brokerCertChainAndKey:
            secretName: ${local.kafka_broker_cert}
            certificate: tls.crt
            key: tls.key

    config:
      message.max.bytes: 4194304
      replica.fetch.max.bytes: 5242880
      unclean.leader.election.enable: false
      min.insync.replicas: 2
      log.message.timestamp.type: CreateTime
      offsets.topic.replication.factor: ${var.default_topic_replication_factor}
      default.replication.factor: ${var.default_topic_replication_factor}
      offsets.retention.minutes: 20160
      auto.create.topics.enable: false
      allow.everyone.if.no.acl.found: true
    authorization:
      type: simple
      superUsers:
        - vault-kafka-init
        - CN=vault-kafka-init
        - CN=vault-kafka-init,OU=vault,O=Thought Machine Ltd,L=London,ST=Greater London,C=GB

  clientsCa:
    generateCertificateAuthority: false

  zookeeper:
    replicas: 3
    storage:
      type: persistent-claim
      size: 20Gi
      deleteClaim: true
    template:
      pod:
        priorityClassName: "platform-support"

  entityOperator:
    topicOperator: {}
    userOperator: {}
EOF
}

#### Users ####

resource "kubectl_manifest" "kafka_init_user_secret" {
  count      = var.kafka_mode == "mtls" ? 0 : 1
  depends_on = [kubectl_manifest.kafka_cluster]
  yaml_body  = <<-EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${local.kafka_init_username}
  namespace: ${helm_release.strimzi.namespace}
data:
  password: ${local.kafka_init_user_base64_password}
  EOF
}

resource "time_sleep" "kafka_init_user_wait" {
  count           = var.kafka_mode == "mtls" ? 0 : 1
  depends_on      = [kubectl_manifest.kafka_init_user_secret]
  create_duration = "3s"
}

resource "kubectl_manifest" "kafka_init_user" {
  depends_on = [time_sleep.kafka_init_user_wait]
  yaml_body = <<-EOF
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: ${local.kafka_init_username}
  namespace: ${helm_release.strimzi.namespace}
  labels:
    strimzi.io/cluster: ${local.kafka_name}
spec:
  authentication:
    type: ${var.kafka_mode == "mtls" ? "tls" : "scram-sha-512"}
    ${var.kafka_mode == "mtls"
? "" : indent(4, trimspace(local.kafka_init_user_password_yaml))}
  EOF
}

resource "kubectl_manifest" "kafka_acl_cleanup_user" {
  count     = var.kafka_mode == "mtls" ? 1 : 0
  yaml_body = <<-EOF
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: vault-kafka-acl-cleanup
  namespace: ${helm_release.strimzi.namespace}
  labels:
    strimzi.io/cluster: ${local.kafka_name}
spec:
  authentication:
    type: tls
  EOF
}

#### Self-signed Root CA ####

# Bootstrapper
resource "kubectl_manifest" "kafka_root_ca_issuer" {
  depends_on = [helm_release.strimzi]
  yaml_body  = <<-EOF
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: kafka-root-ca-issuer
  namespace: ${helm_release.strimzi.namespace}
spec:
  selfSigned: {}
EOF
}

# Root CA Certificate
resource "kubectl_manifest" "kafka_root_ca_certificate" {
  depends_on = [kubectl_manifest.kafka_root_ca_issuer]
  yaml_body  = <<-EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: kafka-root-ca-certificate
  namespace: ${helm_release.strimzi.namespace}
spec:
  isCA: true
  commonName: Kafka Self-Signed Root CA
  secretName: kafka-root-ca-tls # contains ca.crt, tls.crt, tls.key
  issuerRef:
    name: kafka-root-ca-issuer
    kind: Issuer
EOF
}

# Functional CA Issuer
resource "kubectl_manifest" "kafka_ca_issuer" {
  depends_on = [kubectl_manifest.kafka_root_ca_certificate]
  yaml_body  = <<-EOF
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: kafka-ca-issuer
  namespace: ${helm_release.strimzi.namespace}
spec:
  ca:
    secretName: kafka-root-ca-tls
EOF
}

# Usable Kafka Broker Certificate
resource "kubectl_manifest" "kafka_broker_cert" {
  depends_on = [kubectl_manifest.kafka_root_ca_issuer]
  yaml_body  = <<-EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${local.kafka_broker_cert}
  namespace: ${local.kafka_namespace}
spec:
  secretName: ${local.kafka_broker_cert}
  issuerRef:
    name: kafka-ca-issuer
    kind: Issuer
  duration: 2160h
  renewBefore: 360h
  subject:
    organizationalUnits:
      - "kafka"
    organizations:
      - "Thought Machine Ltd"
  dnsNames:
    - "${local.sasl_bootstrap_hostname}"
    - "${local.kafka_subdomain}"
    - "*.${local.kafka_subdomain}"
    - "kafka.svc.cluster.local"
    - "*.kafka.svc.cluster.local"
EOF
}

# Shim to sync from cert manager CA
data "kubernetes_secret" "cert_manager_root_ca" {
  depends_on = [local.dependency, time_sleep.strimzi_reconcile]
  metadata {
    name      = "kafka-root-ca-tls"
    namespace = "kafka"
  }
}

resource "time_sleep" "strimzi_reconcile" {
  depends_on = [helm_release.strimzi]
  create_duration = "60s" # Give the operator time to create the CA
}

# Overwrite the default strimzi client CA key.
resource "kubernetes_secret" "strimzi_client_ca" {
  depends_on = [data.kubernetes_secret.cert_manager_root_ca]
  metadata {
    name      = "${local.kafka_name}-clients-ca"
    namespace = local.kafka_namespace
    labels = {
      "strimzi.io/cluster" = local.kafka_name
      "strimzi.io/kind"    = "Kafka"
    }
  }
  data = {
    "ca.key" = local.ca_key
  }
  type = "Opaque"
}

# Overwrite the default strimzi client CA cert.
resource "kubernetes_secret" "strimzi_client_ca_cert" {
  depends_on = [data.kubernetes_secret.cert_manager_root_ca]
  metadata {
    name      = "${local.kafka_name}-clients-ca-cert"
    namespace = local.kafka_namespace
    labels = {
      "strimzi.io/cluster" = local.kafka_name
      "strimzi.io/kind"    = "Kafka"
    }
  }
  data = {
    "ca.crt" = local.ca_cert
  }
  type = "Opaque"
}
