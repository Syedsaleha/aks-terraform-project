output "mysql_name" {
  value = azurerm_mysql_flexible_server.mysql.name
}

output "mysql_fqdn" {
  value = azurerm_mysql_flexible_server.mysql.fqdn
}

output "mysql_private_endpoint_id" {
  value = var.enable_private_endpoint ? azurerm_private_endpoint.db_pe[0].id : null
}
