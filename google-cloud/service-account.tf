module "gke_service_account" {
  source  = "gruntwork-io/gke/google//modules/gke-service-account"
  version = "0.10.0"

  name        = var.service_account_name
  project     = var.project
  description = "Service Account used for node pool communication"
}

locals {
  all_service_account_roles = concat(var.service_account_roles, [
    "roles/artifactregistry.admin",
    "roles/logging.logWriter",
    "roles/logging.admin",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer"
  ])

  email = "${var.service_account_name}@${var.project}.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "service_account-roles" {
  for_each = toset(local.all_service_account_roles)

  project = var.project
  role    = each.value
  member  = "serviceAccount:${local.email}"

  depends_on = [module.gke_service_account]
}
