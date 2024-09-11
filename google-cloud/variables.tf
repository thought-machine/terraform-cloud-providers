variable "machine_type" {
  type        = string
  description = "machine type that will be used for GKE nodes"
}

variable "region" {
  type        = string
  description = "default region that will be used"
}

variable "project" {
  type        = string
  description = "project id for the resources"
}

variable "network_name" {
  type    = string
  default = "gcp-vpc-network"
}

variable "artifact_region" {
  type        = string
  description = "region for storing vault artifacts and other artifacts required for running vault"
}

variable "k8s_name" {
  type        = string
  description = "k8s cluser name"
}

variable "k8s_version" {
  type        = string
  description = "minimum version for the k8s cluster"
}

variable "project_number" {
  type        = string
  description = "unqiue value globally for all projects on Google Cloud and required for AlloyDB network"
}

variable "registry_name" {
  type        = string
  description = "create a registry with a specific name"
}

variable "bastion_members" {
  type        = list(string)
  description = "List of users, groups, SAs who need access to the bastion host"
  default     = []
}

variable "service_account_name" {
  type        = string
  description = "Service account name that is used for GKE"
}

variable "service_account_roles" {
  type        = list(string)
  description = "List of roles for service account"
  default     = []
}

variable "pipeline-ip" {
  type        = string
  description = "IP Address used for the Pipeline, used to deploy services and Vault"
}
