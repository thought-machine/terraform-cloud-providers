variable "project" {
  type = string
}

variable "project_domain" {
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

variable "kafka_init_sasl_scram_username" {
  type = string
}

variable "kafka_init_sasl_scram_password" {
  type = string
}

variable "kafka_mode" {
  type        = string
  description = "Authentication mode [ sasl-scram | mtls ]"
  default     = "sasl-scram"
  validation {
    condition     = contains(["mtls", "sasl-scram"], var.kafka_mode)
    error_message = "Invalid kafka mode."
  }
}

variable "dependency" {
  type = any
}
