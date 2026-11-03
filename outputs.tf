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

output "policy_assignment_ids" {
  value = {
    require_cost_center = azurerm_resource_group_policy_assignment.require_cost_center.id
    require_project     = azurerm_resource_group_policy_assignment.require_project.id
    allowed_locations   = azurerm_resource_group_policy_assignment.allowed_locations.id
  }
}

output "budget_name" {
  value = azurerm_consumption_budget_resource_group.lab.name
}

output "storage_lock_enabled" {
  value = var.enable_lock
}
