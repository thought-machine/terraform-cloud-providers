resource "google_artifact_registry_repository" "vault_artifacts" {
  project       = var.project
  location      = var.artifact_region
  repository_id = var.registry_name
  description   = "Docker repository for hosting Vault artifacts"
  format        = "DOCKER"
}
