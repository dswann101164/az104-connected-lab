# Storage account names are global, lowercase, no dashes, max 24 chars.
resource "random_string" "storage_suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_storage_account" "lab" {
  name                            = "st${var.workload}${random_string.storage_suffix.result}"
  location                        = azurerm_resource_group.lab.location
  resource_group_name             = azurerm_resource_group.lab.name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  tags                            = var.tags
}

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.lab.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  name                  = "link-vnet-hub"
  resource_group_name   = azurerm_resource_group.lab.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "spoke" {
  for_each = var.spokes

  name                  = "link-vnet-spoke-${each.key}"
  resource_group_name   = azurerm_resource_group.lab.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.spoke[each.key].id
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "blob" {
  name                = "pe-${azurerm_storage_account.lab.name}-blob"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  subnet_id           = azurerm_subnet.pe.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${azurerm_storage_account.lab.name}-blob"
    private_connection_resource_id = azurerm_storage_account.lab.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  # Registers the A record in the zone automatically.
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }

  depends_on = [azurerm_subnet_network_security_group_association.pe]
}
