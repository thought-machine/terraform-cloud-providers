
locals {
  msk_name = "${var.project}-msk"
}

# nosemgrep: resource-not-on-allowlist
resource "aws_msk_cluster" "main" {
  cluster_name           = local.msk_name
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.kafka_broker_replicas

  broker_node_group_info {
    instance_type  = "kafka.t3.small"
    client_subnets = var.private_subnet_ids
    storage_info {
      ebs_storage_info {
        volume_size = 50
      }
    }
    security_groups = [var.app_security_group_id]
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  client_authentication {
    sasl {
      scram = true
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.main.arn
    revision = aws_msk_configuration.main.latest_revision
  }
}

# nosemgrep: resource-not-on-allowlist
resource "aws_msk_configuration" "main" {
  kafka_versions    = [var.kafka_version]
  name              = local.msk_name
  server_properties = <<PROPERTIES
auto.create.topics.enable = false
unclean.leader.election.enable= false
delete.topic.enable = true
default.replication.factor	= ${var.default_topic_replication_factor}
PROPERTIES
}

# nosemgrep customer-created-cmk-key-rotation-enabled
resource "aws_kms_key" "msk_sasl_scram" {
  # https://docs.aws.amazon.com/msk/latest/developerguide/msk-password.html
  description                        = "CMK for AWS SM secret for sasl-scram authentication of MSK cluster ${local.msk_name}"
  deletion_window_in_days            = 7
  key_usage                          = "ENCRYPT_DECRYPT"
  customer_master_key_spec           = "SYMMETRIC_DEFAULT"
  is_enabled                         = true
  multi_region                       = false
  enable_key_rotation                = false
  bypass_policy_lockout_safety_check = false
}

resource "aws_kms_alias" "msk_sasl_scram" {
  name          = "alias/${local.msk_name}-sasl-scram"
  target_key_id = aws_kms_key.msk_sasl_scram.key_id
}
