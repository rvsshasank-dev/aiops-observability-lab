module "network" {
  source = "./modules/network"

  project_id    = var.project_id
  region        = var.region
  name_prefix   = var.name_prefix
  subnet_cidr   = var.network_cidr
  pods_cidr     = var.pods_cidr
  services_cidr = var.services_cidr
  labels        = var.labels
}

module "storage" {
  source = "./modules/storage"

  project_id               = var.project_id
  region                   = var.region
  telemetry_retention_days = var.telemetry_retention_days
  labels                   = var.labels

  # The lab is rebuilt often; do not block destroy on trace/log objects.
  force_destroy = true
}

module "iam" {
  source = "./modules/iam"

  project_id       = var.project_id
  name_prefix      = var.name_prefix
  tempo_bucket     = module.storage.tempo_bucket
  loki_bucket      = module.storage.loki_bucket
  wif_smoke_bucket = module.storage.wif_smoke_bucket
  labels           = var.labels

  depends_on = [module.storage]
}

module "gke" {
  source = "./modules/gke"

  project_id                 = var.project_id
  zone                       = var.zone
  cluster_name               = var.cluster_name
  network_name               = module.network.network_name
  subnet_name                = module.network.subnet_name
  pods_range_name            = module.network.pods_range_name
  services_range_name        = module.network.services_range_name
  master_ipv4_cidr_block     = var.master_ipv4_cidr_block
  node_service_account_email = module.iam.node_service_account_email
  node_machine_type          = var.node_machine_type
  node_min_count             = var.node_min_count
  node_max_count             = var.node_max_count
  node_disk_size_gb          = var.node_disk_size_gb
  release_channel            = var.release_channel
  master_authorized_networks = var.master_authorized_networks
  labels                     = var.labels

  depends_on = [module.network, module.iam]
}
