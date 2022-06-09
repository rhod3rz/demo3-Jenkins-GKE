terraform {
  required_version = "1.0.7"                                  /* Version pin terraform; test upgrades */
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.87.0"                                      /* Version pin provider (https://releases.hashicorp.com/); test upgrades */
    }
  }
  backend "gcs" {
    credentials = "../../../secrets/sa-terraform-211008.json" /* SA key */
    bucket      = "tfstate-dev-211008"                        /* GCS bucket */
    prefix      = "jenkinsfile-dev"                           /* Align with git repo name; this will create jenkinsfile-prd\default.tfstate */
  }
}

provider "google" {
  credentials = "../../../secrets/sa-terraform-211008.json"   /* SA key */
  project     = "devops-211008"
  region      = "europe-west1"
}

module "vpc" {
  env_name                = "dev"                             /* The environment for the vpc/cluster */
  source                  = "../../mod/vpc"                   /* The path to the module */
  project_id              = "devops-211008"                   /* The project ID to host the vpc/cluster in */
  network                 = "gke-network"                     /* The VPC network created to host the cluster in */
  subnetwork              = "gke-subnet"                      /* The subnetwork created to host the cluster in */
  subnetwork_range        = "10.10.0.0/16"                    /* The primary ip range to use for vpc/cluster (cluster hosts) */
  region                  = "europe-west1"                    /* The region to host the vpc/cluster in */
  ip_range_pods_name      = "ip-range-pods"                   /* The secondary ip range name to use for pods */
  ip_range_pods_range     = "10.20.0.0/16"                    /* The secondary ip range range to use for pods */
  ip_range_services_name  = "ip-range-services"               /* The secondary ip range name to use for services */
  ip_range_services_range = "10.30.0.0/16"                    /* The secondary ip range range to use for services */
}

module "gke" {
  env_name                = "dev"                             /* The environment for the vpc/cluster */
  source                  = "../../mod/gke"                   /* The path to the module */
  project_id              = "devops-211008"                   /* The project ID to host the vpc/cluster in */
  cluster_name            = "sz-211008-0911"                  /* The name for the gke cluster */
  region                  = "europe-west1"                    /* The region to host the vpc/cluster in */
  zones                   = "europe-west1-b"                  /* The zones to host the vpc/cluster in */
  network                 = module.vpc.network                /* The network to host the vpc/cluster in */
  subnetwork              = module.vpc.subnetwork             /* The subnetwork to host the vpc/cluster in */
  ip_range_pods_name      = "ip-range-pods"                   /* The secondary ip range name to use for pods */
  ip_range_services_name  = "ip-range-services"               /* The secondary ip range name to use for services */
  machine_type            = "n1-standard-1"                   /* The secondary ip range name to use for services */
}
