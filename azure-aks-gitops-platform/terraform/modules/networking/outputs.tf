output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "aks_subnet_id" {
  value = azurerm_subnet.aks.id
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.this.id
}
