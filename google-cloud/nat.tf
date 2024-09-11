resource "google_compute_router" "router" {
  project = var.project
  name    = "public-router"
  network = google_compute_network.gcp-vpc-network.name
  region  = var.region
}

## Create Nat Gateway
resource "google_compute_router_nat" "nat" {
  project                            = var.project
  name                               = "vault-public-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"


  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
