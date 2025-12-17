# Create Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "${var.project_name}-${var.environment}-rg"
  location = var.location
}

# Create Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.project_name}-${var.environment}-vnet"
  address_space       = var.address_space
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create NSG for each subnet (except private-endpoints - NSGs don't apply when network policies are disabled)
resource "azurerm_network_security_group" "nsgs" {
  for_each = { for k, v in var.subnets : k => v if k != "private-endpoints" }

  name                = "${var.project_name}-${var.environment}-${each.key}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create Subnets with NSG attached
resource "azurerm_subnet" "subnets" {
  for_each             = var.subnets
  name                 = each.key
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = each.value.address_prefixes

  # Disable network policies for private-endpoints subnet (required for private endpoints)
  # Private endpoints bypass NSG/UDR rules for simplified connectivity
  private_endpoint_network_policies = each.key == "private-endpoints" ? "Disabled" : "Enabled"
}

# Associate NSG with Subnets (except private-endpoints - not needed when network policies are disabled)
resource "azurerm_subnet_network_security_group_association" "subnet_nsg_assoc" {
  for_each                  = { for k, v in var.subnets : k => v if k != "private-endpoints" }
  subnet_id                 = azurerm_subnet.subnets[each.key].id
  network_security_group_id = azurerm_network_security_group.nsgs[each.key].id
}

# Network Security Rules
# AKS subnet NSG rules - simplified and non-overlapping
resource "azurerm_network_security_rule" "aks_allow_azure_lb" {
  count                  = contains(keys(var.subnets), "aks") ? 1 : 0
  name                   = "${var.project_name}-${var.environment}-aks-allow-azurelb"
  priority               = 100
  direction              = "Inbound"
  access                 = "Allow"
  protocol               = "*"
  source_port_range      = "*"
  destination_port_range = "*"

  source_address_prefix      = "AzureLoadBalancer"
  destination_address_prefix = "*"

  network_security_group_name = azurerm_network_security_group.nsgs["aks"].name
  resource_group_name         = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "aks_allow_vnet" {
  count                  = contains(keys(var.subnets), "aks") ? 1 : 0
  name                   = "${var.project_name}-${var.environment}-aks-allow-vnet"
  priority               = 110
  direction              = "Inbound"
  access                 = "Allow"
  protocol               = "*"
  source_port_range      = "*"
  destination_port_range = "*"

  source_address_prefix      = "VirtualNetwork"
  destination_address_prefix = "VirtualNetwork"

  network_security_group_name = azurerm_network_security_group.nsgs["aks"].name
  resource_group_name         = azurerm_resource_group.rg.name
}

# Allow HTTP/HTTPS traffic from Internet to Ingress Controller
resource "azurerm_network_security_rule" "aks_allow_http_https" {
  count                   = contains(keys(var.subnets), "aks") ? 1 : 0
  name                    = "${var.project_name}-${var.environment}-aks-allow-http-https"
  priority                = 200
  direction               = "Inbound"
  access                  = "Allow"
  protocol                = "Tcp"
  source_port_range       = "*"
  destination_port_ranges = ["80", "443"]

  source_address_prefix      = "Internet"
  destination_address_prefix = "*"

  network_security_group_name = azurerm_network_security_group.nsgs["aks"].name
  resource_group_name         = azurerm_resource_group.rg.name
}

# Deny all other inbound Internet traffic
resource "azurerm_network_security_rule" "aks_deny_internet" {
  count                  = contains(keys(var.subnets), "aks") ? 1 : 0
  name                   = "${var.project_name}-${var.environment}-aks-deny-internet"
  priority               = 4000
  direction              = "Inbound"
  access                 = "Deny"
  protocol               = "*"
  source_port_range      = "*"
  destination_port_range = "*"

  source_address_prefix      = "Internet"
  destination_address_prefix = "*"

  network_security_group_name = azurerm_network_security_group.nsgs["aks"].name
  resource_group_name         = azurerm_resource_group.rg.name
}

# Note: Private endpoints subnet has minimal NSG rules
# Private endpoints bypass NSG rules by default (network policies disabled)
# Security is enforced through VNet isolation, private DNS, and service-level authentication

# Optional: User Defined Route (UDR) for private subnets
resource "azurerm_route_table" "private" {
  count               = var.enable_udr ? 1 : 0
  name                = "${var.project_name}-${var.environment}-private-rt"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet_route_table_association" "private_assoc" {
  for_each       = { for k, v in azurerm_subnet.subnets : k => v if k == "aks" || k == "database" }
  subnet_id      = each.value.id
  route_table_id = azurerm_route_table.private[0].id
}

# NAT Gateway resources for egress (created only when an `egress` subnet is defined)
resource "azurerm_public_ip" "nat_ip" {
  count               = contains(keys(var.subnets), "egress") ? 1 : 0
  name                = "${var.project_name}-${var.environment}-nat-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "nat" {
  count               = contains(keys(var.subnets), "egress") ? 1 : 0
  name                = "${var.project_name}-${var.environment}-nat"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard"
}

# Associate Public IP(s) to the NAT Gateway using the association resource
resource "azurerm_nat_gateway_public_ip_association" "nat_ip_assoc" {
  count = contains(keys(var.subnets), "egress") ? length(azurerm_public_ip.nat_ip) : 0

  nat_gateway_id       = azurerm_nat_gateway.nat[0].id
  public_ip_address_id = element(azurerm_public_ip.nat_ip[*].id, count.index)
}

# Associate the NAT gateway with the egress subnet when present
resource "azurerm_subnet_nat_gateway_association" "egress_assoc" {
  count = contains(keys(var.subnets), "egress") ? 1 : 0

  subnet_id      = azurerm_subnet.subnets["egress"].id
  nat_gateway_id = azurerm_nat_gateway.nat[0].id
}

# Also attach the NAT Gateway to the AKS subnet so AKS uses the stable NAT egress IPs
resource "azurerm_subnet_nat_gateway_association" "aks_assoc" {
  count = contains(keys(var.subnets), "egress") && contains(keys(var.subnets), "aks") ? 1 : 0

  subnet_id      = azurerm_subnet.subnets["aks"].id
  nat_gateway_id = azurerm_nat_gateway.nat[0].id
  #nat_gateway_id = azurerm_nat_gateway.nat[0].id
}