module "vpc" {
  source       = "terraform-google-modules/network/google"
  version      = "2.6.0"
  project_id   = var.project_id
  network_name = "${var.network}-${var.env_name}"
  subnets = [
    {
      subnet_name   = "${var.subnetwork}-${var.env_name}"
      subnet_ip     = var.subnetwork_range
      subnet_region = var.region
    }
  ]
  secondary_ranges = {
    "${var.subnetwork}-${var.env_name}" = [
      {
        range_name    = var.ip_range_pods_name
        ip_cidr_range = var.ip_range_pods_range
      },
      {
        range_name    = var.ip_range_services_name
        ip_cidr_range = var.ip_range_services_range
      }
    ]
  }
}
