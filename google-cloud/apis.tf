module "enabled_google_apis" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 14.0"

  project_id                  = var.project
  disable_services_on_destroy = false

  activate_apis = [
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
    "compute.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "container.googleapis.com",
    "binaryauthorization.googleapis.com",
    "networkconnectivity.googleapis.com",
    "iap.googleapis.com",
    "alloydb.googleapis.com",
    "artifactregistry.googleapis.com",
  ]
}
