output "cluster_name" {
  value = local.kafka_name
}

output "strimzi_kafka_ca_cert_path" {
  value = "${local.strimzi_kafka_ssl_dir_path}/ca.crt"
}

output "strimzi_kafka_tls_cert_path" {
  value = "${local.strimzi_kafka_ssl_dir_path}/tls.crt"
}

output "bootstrap_brokers_sasl_scram" {
  value = "${local.sasl_broker_hostnames[0]}:443,${local.sasl_broker_hostnames[1]}:443,${local.sasl_broker_hostnames[2]}:443"
}

output "bootstrap_brokers_mtls" {
  value = "${local.mtls_broker_hostnames[0]}:443,${local.mtls_broker_hostnames[1]}:443,${local.mtls_broker_hostnames[2]}:443"
}
