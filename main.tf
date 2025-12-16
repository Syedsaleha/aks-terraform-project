module "network" {
  source        = "./modules/network"
  project_name  = var.project_name
  environment   = var.environment
  location      = var.location
  address_space = var.address_space
  subnets       = var.subnets
  enable_udr    = true
  dns_zone_name = var.dns_zone_name
}

module "aks" {
  source                 = "./modules/aks"
  project_name           = var.project_name
  environment            = var.environment
  location               = var.location
  aks_min_count          = var.aks_min_count
  aks_max_count          = var.aks_max_count
  subnet_ids             = module.network.subnet_ids
  resource_group_name    = module.network.resource_group_name
  enable_private_cluster = var.enable_private_aks_cluster
  create_role_assignment = var.create_aks_admin_role_assignment
  dns_zone_name          = var.dns_zone_name
}

module "mysql" {
  source                  = "./modules/mysql"
  project_name            = var.project_name
  environment             = var.environment
  location                = var.location
  mysql_admin_username    = var.mysql_admin_username
  mysql_admin_password    = var.mysql_admin_password
  subnet_ids              = module.network.subnet_ids
  resource_group_name     = module.network.resource_group_name
  vnet_id                 = module.network.vnet_id
  unique_suffix           = local.unique_suffix
  enable_private_endpoint = var.create_private_endpoints
}

module "acr" {
  source                  = "./modules/acr"
  project_name            = var.project_name
  environment             = var.environment
  location                = var.location
  secondary_location      = var.secondary_location
  acr_sku                 = var.acr_sku
  resource_group_name     = module.network.resource_group_name
  private_subnet_id       = lookup(module.network.subnet_ids, "private-endpoints", "")
  vnet_id                 = module.network.vnet_id
  enable_private_endpoint = var.create_private_endpoints
  unique_suffix           = local.unique_suffix
}

module "keyvault" {
  source              = "./modules/keyvault"
  project_name        = var.project_name
  environment         = var.environment
  location            = var.location
  sku                 = var.kv_sku
  resource_group_name = module.network.resource_group_name
  tags = {
    environment = var.environment
    project     = var.project_name
  }
  private_subnet_id       = lookup(module.network.subnet_ids, "private-endpoints", "")
  vnet_id                 = module.network.vnet_id
  enable_private_endpoint = var.create_private_endpoints
  allowed_ip_ranges       = [] # Empty list for now, can be configured per environment
}

# Grant AKS managed identity permission to pull images from ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  count                            = var.create_acr_role_assignment ? 1 : 0
  scope                            = module.acr.acr_id
  role_definition_name             = "AcrPull"
  principal_id                     = module.aks.kubelet_identity_object_id
  skip_service_principal_aad_check = true
}
