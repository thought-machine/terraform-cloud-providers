resource "google_container_cluster" "vault_cluster" {
  provider = "google-beta"

  project             = var.project
  name                = var.k8s_name
  location            = var.region
  network             = google_compute_network.gcp-vpc-network.name
  subnetwork          = google_compute_subnetwork.europe-west2-network-with-private-secondary-ip-ranges.name
  min_master_version  = var.k8s_version
  deletion_protection = false

  //removing initial node pool after creation to enable to better management
  initial_node_count       = 1
  remove_default_node_pool = true

  release_channel {
    //you should ensure this is set to STABLE for a production environment
    channel = "RAPID"
  }

  private_cluster_config {
    enable_private_endpoint = false
    enable_private_nodes    = true
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.pipeline-ip
      display_name = "pipeline host"
    }
  }
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "/14"
    services_ipv4_cidr_block = "/20"
  }

  cluster_autoscaling {
    enabled             = true
    autoscaling_profile = "OPTIMIZE_UTILIZATION"
    resource_limits {
      resource_type = "memory"
      minimum       = 8
      maximum       = 64

    }
    resource_limits {
      resource_type = "cpu"
      minimum       = 1
      maximum       = 10
    }
    # This structure contains defaults for a node pool created by NAP (Node Auto-provisioning)
    auto_provisioning_defaults {
      service_account = module.gke_service_account.email
      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
    }
  }

}

resource "google_container_node_pool" "default_node_pool" {
  provider = google-beta

  name               = "linux-pool"
  project            = google_container_cluster.vault_cluster.project
  cluster            = google_container_cluster.vault_cluster.name
  location           = google_container_cluster.vault_cluster.location
  initial_node_count = 0

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  upgrade_settings {
    strategy = "BLUE_GREEN"
    blue_green_settings {
      node_pool_soak_duration = "600s"
      standard_rollout_policy {
        batch_node_count    = 2
        batch_soak_duration = "300s"
      }
    }
  }


  node_config {
    image_type      = "COS_CONTAINERD"
    machine_type    = var.machine_type
    service_account = module.gke_service_account.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    gcfs_config {
      enabled = true
    }
  }
}

resource "google_container_node_pool" "spot-node-pool" {
  name               = "spot-pool"
  project            = google_container_cluster.vault_cluster.project
  cluster            = google_container_cluster.vault_cluster.name
  location           = google_container_cluster.vault_cluster.location
  initial_node_count = 6

  autoscaling {
    min_node_count = 3
    max_node_count = 6
  }

  upgrade_settings {
    strategy = "BLUE_GREEN"
    blue_green_settings {
      node_pool_soak_duration = "600s"
      standard_rollout_policy {
        batch_node_count    = 2
        batch_soak_duration = "300s"
      }
    }
  }

  node_config {
    image_type      = "COS_CONTAINERD"
    machine_type    = var.machine_type
    service_account = module.gke_service_account.email
    spot            = true
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    taint {
      key    = "instance_type"
      value  = "spot"
      effect = "NO_SCHEDULE"
    }

    gcfs_config {
      enabled = true
    }
  }
}
