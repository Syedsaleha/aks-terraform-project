
data "azurerm_client_config" "current" {}

# Random suffix to avoid global Key Vault name conflict
resource "random_string" "suffix" {
  length  = 4
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_key_vault" "kv" {
  name                          = "${var.project_name}-${var.environment}-kv-${random_string.suffix.result}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku_name                      = var.sku
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days    = 7
  purge_protection_enabled      = true
  public_network_access_enabled = var.enable_private_endpoint ? false : true
  tags                          = var.tags

  network_acls {
    bypass         = "AzureServices"
    default_action = var.enable_private_endpoint ? "Deny" : (length(var.allowed_ip_ranges) > 0 ? "Deny" : "Allow")
    ip_rules       = var.allowed_ip_ranges
  }

  # Recommended access policy block can be added here if needed
}

# Private DNS Zone for Key Vault Private Link
resource "azurerm_private_dns_zone" "keyvault" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
}

# Link Private DNS Zone to VNet
# This enables AKS pods to resolve the Key Vault private endpoint FQDN
resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  count                 = var.enable_private_endpoint ? 1 : 0
  name                  = "${var.project_name}-${var.environment}-kv-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault[0].name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false

  depends_on = [azurerm_private_dns_zone.keyvault]
}

# Private Endpoint for Key Vault in dedicated private-endpoints subnet
resource "azurerm_private_endpoint" "kv_pe" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "${var.project_name}-${var.environment}-kv-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_subnet_id

  private_service_connection {
    name                           = "${var.project_name}-${var.environment}-kv-psc"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_key_vault.kv.id
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "keyvault-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.keyvault[0].id]
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.keyvault,
    azurerm_key_vault.kv
  ]
}
