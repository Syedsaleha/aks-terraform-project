resource "azurerm_container_registry" "acr" {
  name                          = var.unique_suffix != "" ? "${var.project_name}${var.environment}acr${var.unique_suffix}" : "${var.project_name}${var.environment}acr"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = var.acr_sku
  admin_enabled                 = false
  public_network_access_enabled = !var.enable_private_endpoint

  # network_rule_set is only supported for Premium SKU
  dynamic "network_rule_set" {
    for_each = var.acr_sku == "Premium" ? [1] : []
    content {
      default_action = var.enable_private_endpoint ? "Deny" : "Allow"
    }
  }

  dynamic "georeplications" {
    for_each = var.acr_sku == "Premium" ? [1] : []
    content {
      location                = var.secondary_location
      zone_redundancy_enabled = true
    }
  }

  tags = {
    environment = var.environment
    project     = var.project_name
  }
}

# Private DNS Zone for ACR Private Link
resource "azurerm_private_dns_zone" "acr" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "privatelink.azurecr.io"
  resource_group_name = var.resource_group_name
}

# Link Private DNS Zone to VNet
# This enables AKS pods to resolve the ACR private endpoint FQDN
resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  count                 = var.enable_private_endpoint ? 1 : 0
  name                  = "${var.project_name}-${var.environment}-acr-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.acr[0].name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false

  depends_on = [azurerm_private_dns_zone.acr]
}

# Private Endpoint for ACR in dedicated private-endpoints subnet
resource "azurerm_private_endpoint" "acr_pe" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "${var.project_name}-${var.environment}-acr-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_subnet_id

  private_service_connection {
    name                           = "${var.project_name}-${var.environment}-acr-psc"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_container_registry.acr.id
    subresource_names              = ["registry"]
  }

  private_dns_zone_group {
    name                 = "acr-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr[0].id]
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.acr,
    azurerm_container_registry.acr
  ]
}
