# Hub

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = [var.hub_address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "pe" {
  name                              = "snet-pe"
  resource_group_name               = azurerm_resource_group.lab.name
  virtual_network_name              = azurerm_virtual_network.hub.name
  address_prefixes                  = [var.pe_subnet_prefix]
  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_network_security_group" "pe" {
  name                = "nsg-snet-pe"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "pe" {
  subnet_id                 = azurerm_subnet.pe.id
  network_security_group_id = azurerm_network_security_group.pe.id
}

# Bastion (Basic SKU reaches VMs in peered spokes; Developer SKU does not)

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet" # name required by Azure
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.bastion_subnet_prefix]
}

# An NSG on AzureBastionSubnet must carry this exact rule set or Bastion fails.
# https://learn.microsoft.com/azure/bastion/bastion-nsg
locals {
  bastion_nsg_rules = {
    AllowHttpsInbound = {
      priority = 120, direction = "Inbound", ports = ["443"]
      source   = "Internet", destination = "*"
    }
    AllowGatewayManagerInbound = {
      priority = 130, direction = "Inbound", ports = ["443"]
      source   = "GatewayManager", destination = "*"
    }
    AllowAzureLoadBalancerInbound = {
      priority = 140, direction = "Inbound", ports = ["443"]
      source   = "AzureLoadBalancer", destination = "*"
    }
    AllowBastionHostCommunicationInbound = {
      priority = 150, direction = "Inbound", ports = ["8080", "5701"]
      source   = "VirtualNetwork", destination = "VirtualNetwork"
    }
    AllowSshRdpOutbound = {
      priority = 100, direction = "Outbound", ports = ["22", "3389"]
      source   = "*", destination = "VirtualNetwork"
    }
    AllowAzureCloudOutbound = {
      priority = 110, direction = "Outbound", ports = ["443"]
      source   = "*", destination = "AzureCloud"
    }
    AllowBastionCommunicationOutbound = {
      priority = 120, direction = "Outbound", ports = ["8080", "5701"]
      source   = "VirtualNetwork", destination = "VirtualNetwork"
    }
    AllowHttpOutbound = {
      priority = 130, direction = "Outbound", ports = ["80"]
      source   = "*", destination = "Internet"
    }
  }
}

resource "azurerm_network_security_group" "bastion" {
  name                = "nsg-snet-bastion"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = var.tags

  dynamic "security_rule" {
    for_each = local.bastion_nsg_rules

    content {
      name                       = security_rule.key
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = security_rule.value.ports
      source_address_prefix      = security_rule.value.source
      destination_address_prefix = security_rule.value.destination
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "bastion" {
  subnet_id                 = azurerm_subnet.bastion.id
  network_security_group_id = azurerm_network_security_group.bastion.id
}

# The host and its public IP are the billed parts; var.enable_bastion toggles only these.
resource "azurerm_public_ip" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name                = "pip-bas-hub"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "hub" {
  count = var.enable_bastion ? 1 : 0

  name                = "bas-hub"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "Basic"
  tags                = var.tags

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }

  # Bastion validates the subnet's NSG at create time.
  depends_on = [azurerm_subnet_network_security_group_association.bastion]
}

# Spokes

resource "azurerm_virtual_network" "spoke" {
  for_each = var.spokes

  name                = "vnet-spoke-${each.key}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = [each.value.address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "spoke" {
  for_each = var.spokes

  name                 = each.value.subnet_name
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.spoke[each.key].name
  address_prefixes     = [each.value.subnet_prefix]
}

resource "azurerm_network_security_group" "spoke" {
  for_each = var.spokes

  name                = "nsg-${each.value.subnet_name}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "spoke" {
  for_each = var.spokes

  subnet_id                 = azurerm_subnet.spoke[each.key].id
  network_security_group_id = azurerm_network_security_group.spoke[each.key].id
}

# Peering, both directions per spoke

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = var.spokes

  name                      = "peer-hub-to-${each.key}"
  resource_group_name       = azurerm_resource_group.lab.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke[each.key].id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each = var.spokes

  name                      = "peer-${each.key}-to-hub"
  resource_group_name       = azurerm_resource_group.lab.name
  virtual_network_name      = azurerm_virtual_network.spoke[each.key].name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}
