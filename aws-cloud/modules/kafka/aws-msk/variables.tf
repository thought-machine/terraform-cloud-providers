variable "project" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "app_security_group_id" {
  type = string
}

variable "kafka_version" {
  type    = string
  default = "3.9.0"
}

variable "kafka_broker_replicas" {
  type    = number
  default = 3
}

variable "default_topic_replication_factor" {
  type    = number
  default = 3
}
