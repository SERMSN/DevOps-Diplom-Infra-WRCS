module "network" {
  source       = "./modules/network"
  network_name = var.network_name
  folder_id    = var.yc_folder_id
  subnets      = var.subnets
}

module "security_groups" {
  source                       = "./modules/security-groups"
  folder_id                    = var.yc_folder_id
  network_id                   = module.network.network_id
  name_prefix                  = var.cluster_name
  cluster_ipv4_range           = var.cluster_ipv4_range
  service_ipv4_range           = var.service_ipv4_range
  kubernetes_api_allowed_cidrs = var.kubernetes_api_allowed_cidrs
  ssh_allowed_cidrs            = var.ssh_allowed_cidrs
}

module "service_accounts" {
  source   = "./modules/service-accounts"
  folder_id = var.yc_folder_id
  service_account_name = "${var.cluster_name}-sa"
  service_account_roles = [
    "k8s.clusters.agent",
    "vpc.publicAdmin",
    "container-registry.images.puller",
    "kms.keys.encrypterDecrypter",
    "load-balancer.admin"
  ]
}

module "kms" {
  source      = "./modules/kms"
  folder_id   = var.yc_folder_id
  key_name    = var.kms_key_name
  description = "KMS key for Managed Kubernetes secrets encryption"
}

module "registry" {
  source    = "./modules/registry"
  folder_id = var.yc_folder_id
  name      = var.registry_name
}

module "kubernetes" {
  source                   = "./modules/kubernetes"
  folder_id                = var.yc_folder_id
  cluster_name             = var.cluster_name
  cluster_description      = var.cluster_description
  cluster_version          = var.cluster_version
  release_channel          = var.release_channel
  network_id               = module.network.network_id
  master_locations         = module.network.subnet_locations
  master_security_group_ids = [
    module.security_groups.cluster_nodegroup_traffic_security_group_id,
    module.security_groups.kubernetes_api_security_group_id
  ]
  service_account_id       = module.service_accounts.service_account_id
  node_service_account_id  = module.service_accounts.service_account_id
  kms_key_id               = module.kms.key_id
  cluster_ipv4_range       = var.cluster_ipv4_range
  service_ipv4_range       = var.service_ipv4_range
  master_public_ip         = var.master_public_ip
  create_node_group        = var.create_node_group
  node_group_name          = var.node_group_name
  node_group_description   = var.node_group_description
  node_count               = var.node_count
  node_platform_id         = var.node_platform_id
  node_cores               = var.node_cores
  node_memory              = var.node_memory
  node_core_fraction       = var.node_core_fraction
  node_disk_type           = var.node_disk_type
  node_disk_size           = var.node_disk_size
  node_preemptible         = var.node_preemptible
  node_subnet_ids          = module.network.subnet_ids
  node_locations           = module.network.subnet_locations
  node_security_group_ids  = [
    module.security_groups.cluster_nodegroup_traffic_security_group_id,
    module.security_groups.public_services_security_group_id,
    module.security_groups.ssh_security_group_id
  ]

  depends_on = [
    module.service_accounts
  ]
}
