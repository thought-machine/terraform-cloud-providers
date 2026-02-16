output "cluster_name" {
  value = aws_msk_cluster.main.cluster_name
}

output "bootstrap_brokers_sasl_scram" {
  value = aws_msk_cluster.main.bootstrap_brokers_sasl_scram
}

output "msk_cluster_arn" {
  value = aws_msk_cluster.main.arn
}

output "msk_sasl_scram_cmk_arn" {
  value = aws_kms_key.msk_sasl_scram.arn
}
