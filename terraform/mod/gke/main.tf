module "gke_auth" {
  source = "terraform-google-modules/kubernetes-engine/google//modules/auth"
  depends_on   = [module.gke]
  project_id   = var.project_id
  location     = module.gke.location
  cluster_name = module.gke.name
}

resource "local_file" "kubeconfig" {
  content  = module.gke_auth.kubeconfig_raw
  filename = "kubeconfig-${var.env_name}"
  lifecycle {
    ignore_changes = all
  }
}

module "gke" {
  source                   = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  project_id               = var.project_id
  name                     = "${var.cluster_name}-${var.env_name}"
  regional                 = false
  region                   = var.region
  zones                    = [var.zones]
  network                  = var.network
  subnetwork               = var.subnetwork
  ip_range_pods            = var.ip_range_pods_name
  ip_range_services        = var.ip_range_services_name

  remove_default_node_pool = true
  node_pools = [
    {
      name                      = "node-pool-1"
      machine_type              = var.machine_type
      node_locations            = "europe-west1-b"
      min_count                 = 1
      max_count                 = 2
      disk_size_gb              = 30
      image_type                = "COS_CONTAINERD"
    }
  ]

}
