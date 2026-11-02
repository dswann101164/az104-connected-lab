variable "subscription_id" {
  description = "Azure subscription to deploy into."
  type        = string
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus2"
}

variable "workload" {
  description = "Short name used in resource names."
  type        = string
  default     = "az104"
}

variable "resource_group_name" {
  description = "Resource group for the connected lab."
  type        = string
  default     = "rg-az104-connected"
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    project     = "az104-connected-lab"
    environment = "lab"
    owner       = "lab-owner"
    managed_by  = "terraform"
  }
}

variable "hub_address_space" {
  description = "Address space for the hub VNet."
  type        = string
  default     = "10.10.0.0/16"
}

variable "spokes" {
  description = "Spoke VNets, each with one workload subnet."
  type = map(object({
    address_space = string
    subnet_name   = string
    subnet_prefix = string
  }))
  default = {
    web = {
      address_space = "10.20.0.0/16"
      subnet_name   = "snet-web"
      subnet_prefix = "10.20.1.0/24"
    }
    db = {
      address_space = "10.30.0.0/16"
      subnet_name   = "snet-db"
      subnet_prefix = "10.30.1.0/24"
    }
  }
}

variable "enable_bastion" {
  description = "Deploy the Bastion host and its public IP (~$142/month). Set false between study sessions; the subnet and NSG stay."
  type        = bool
  default     = true
}

variable "bastion_subnet_prefix" {
  description = "Hub AzureBastionSubnet; /26 or larger."
  type        = string
  default     = "10.10.0.0/26"
}

variable "pe_subnet_prefix" {
  description = "Hub subnet for private endpoints."
  type        = string
  default     = "10.10.1.0/24"
}
