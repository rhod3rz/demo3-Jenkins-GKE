output "network"    { value = module.vpc.network_name }
output "subnetwork" { value = module.vpc.subnets_names[0] }
