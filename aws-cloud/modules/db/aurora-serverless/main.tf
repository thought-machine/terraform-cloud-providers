locals {
  rds_name = "${var.project}-rds"
}

module "aurora_postgresql_v2" {
  source                      = "terraform-aws-modules/rds-aurora/aws"
  version                     = "~> 9.16.1"
  name                        = local.rds_name
  engine                      = "aurora-postgresql"
  engine_mode                 = "provisioned"
  engine_version              = var.postgres_version
  storage_encrypted           = true
  master_username             = var.master_username
  master_password             = var.master_password
  manage_master_user_password = false
  iam_database_authentication_enabled = true
  vpc_id                      = var.vpc_id
  db_subnet_group_name        = var.database_subnet_group_name
  security_group_rules = {
    app_security_group_ingress = {
      source_security_group_id = var.app_security_group_id
    }
  }
  monitoring_interval = 60
  apply_immediately   = true
  skip_final_snapshot = true
  serverlessv2_scaling_configuration = {
    min_capacity             = 0
    max_capacity             = 10
    seconds_until_auto_pause = 3600
  }
  instance_class = "db.serverless"
  instances = {
    one = {}
  }
  cluster_performance_insights_enabled = true
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.pg.name
}

resource "aws_rds_cluster_parameter_group" "pg" {
  name        = local.rds_name
  family      = "aurora-postgresql16"
  description = "Aurora cluster parameter group for pg_stat_statements"
  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
  }
}
