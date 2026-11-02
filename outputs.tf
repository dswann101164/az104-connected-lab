output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "hub_vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "spoke_vnet_ids" {
  value = { for k, v in azurerm_virtual_network.spoke : k => v.id }
}

output "spoke_subnet_ids" {
  value = { for k, v in azurerm_subnet.spoke : k => v.id }
}

output "bastion_enabled" {
  value = var.enable_bastion
}

output "storage_account_name" {
  value = azurerm_storage_account.lab.name
}

output "storage_blob_private_ip" {
  value = azurerm_private_endpoint.blob.private_service_connection[0].private_ip_address
}
