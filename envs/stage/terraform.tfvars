project_name = "cloudproj"
environment  = "stage"
location     = "eastus2"

address_space = ["10.20.0.0/16"]

subnets = {
  egress            = { address_prefixes = ["10.20.1.0/24"] }
  aks               = { address_prefixes = ["10.20.2.0/24"] }
  database          = { address_prefixes = ["10.20.3.0/24"] }
  private-endpoints = { address_prefixes = ["10.20.4.0/24"] } # Dedicated subnet for private endpoints
}

aks_min_count = 3
aks_max_count = 6

mysql_admin_username = "adminuser"
# Do NOT commit secrets. Set `mysql_admin_password` in CI secret store
# Example: in GitHub Actions use `${{ secrets.STAGE_MYSQL_PASSWORD }}` and pass
# it as `-var="mysql_admin_password=${{ secrets.STAGE_MYSQL_PASSWORD }}"`
# mysql_admin_password = "<SET_IN_CI>"

# Security settings - ENABLED for stage environment (production-grade security)
create_private_endpoints   = true
enable_private_aks_cluster = true

# ACR Integration - Grant AKS permission to pull images from ACR
create_acr_role_assignment = true
