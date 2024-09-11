resource "random_password" "password" {
  length           = 12
  special          = false
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "google_alloydb_instance" "vault_db" {
  cluster       = google_alloydb_cluster.vault_db.name
  instance_id   = "alloydb-instance"
  instance_type = "PRIMARY"


  machine_config {
    cpu_count = 8
  }

}

resource "google_alloydb_cluster" "vault_db" {
  provider   = google-beta
  cluster_id = "alloydb-cluster"
  location   = var.region

  network_config {
    network = google_compute_network.gcp-vpc-network.id
  }

  continuous_backup_config {
    enabled = false
  }

  initial_user {
    user     = "vault-admin"
    password = random_password.password.result
  }

  depends_on = [google_service_networking_connection.default]

}
