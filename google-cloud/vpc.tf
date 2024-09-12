resource "google_compute_network" "gcp-vpc-network" {
  project                         = var.project
  name                            = var.network_name
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = false
}

resource "google_compute_subnetwork" "europe-west2-network-with-private-secondary-ip-ranges" {
  project                  = var.project
  name                     = "${var.region}-subnetwork"
  ip_cidr_range            = "10.2.0.0/16"
  region                   = var.region
  network                  = google_compute_network.gcp-vpc-network.id
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 1.0
    metadata             = "INCLUDE_ALL_METADATA"
  }

  secondary_ip_range {
    range_name    = "vault-secondary-range-private"
    ip_cidr_range = "192.168.10.0/24"
  }

}

resource "google_project_service" "service_networking" {
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
  project            = var.project
}

resource "google_compute_global_address" "private_ip_alloc" {
  name          = "service-private-ip"
  project       = var.project
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.gcp-vpc-network.id
}

resource "google_service_networking_connection" "default" {
  network                 = google_compute_network.gcp-vpc-network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
}
