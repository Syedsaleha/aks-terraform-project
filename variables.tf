variable "project_name" {}
variable "environment" {}

variable "resource_suffix" {
  type        = string
  description = "Unique suffix for globally unique resource names (ACR, MySQL). Use initials + date or random number."
  default     = ""
}

variable "location" {
  default = "eastus"
}

variable "address_space" {
  type = list(string)
}

variable "subnets" {
  type = map(object({
    address_prefixes = list(string)
  }))
}

variable "aks_node_count" {
  type        = number
  description = "Deprecated - use aks_min_count and aks_max_count for auto-scaling"
  default     = 2
}

variable "aks_min_count" {
  type        = number
  description = "Minimum number of nodes when auto-scaling is enabled"
  default     = 1
}

variable "aks_max_count" {
  type        = number
  description = "Maximum number of nodes when auto-scaling is enabled"
  default     = 5
}

variable "mysql_admin_username" {}
variable "mysql_admin_password" {
  sensitive = true
}

variable "kv_sku" {
  default = "standard"
}

variable "create_private_endpoints" {
  type        = bool
  description = "Global flag to enable creation of optional private endpoints for modules that support them (ACR, Key Vault). Set to true to create private endpoints."
  default     = true
}

variable "enable_private_aks_cluster" {
  type        = bool
  description = "Enable private AKS cluster (API server accessible only via private network)"
  default     = true
}

variable "create_acr_role_assignment" {
  type        = bool
  description = "Whether to create ACR pull role assignment for AKS. Set to false if you lack Microsoft.Authorization/roleAssignments/write permissions."
  default     = false
}

variable "create_aks_admin_role_assignment" {
  type        = bool
  description = "Whether to create AKS admin role assignment for the service principal. Set to true to allow CI/CD pipelines to manage the cluster."
  default     = true
}

variable "secondary_location" {
  description = "Secondary Azure region for ACR geo-replication"
  type        = string
  default     = "eastus2"
}

variable "acr_sku" {
  description = "SKU for Azure Container Registry. Use 'Premium' for geo-replication."
  type        = string
  default     = "Standard"
}

variable "dns_zone_name" {
  description = "The DNS zone name to be used by the AKS module."
  type        = string
}