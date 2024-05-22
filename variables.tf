# ======================================================================================
# General
# ======================================================================================
variable "tags" {
  type = map(any)
}


# ======================================================================================
# Resource Group
# ======================================================================================
variable "resource_group_name" {
  description = "Name of the resource group in which the AKS will be created"
  type        = string
}

# ======================================================================================
# Active Directory Group
# ======================================================================================
variable "aks_admin_group" {
  description = "Information required for the creation or the retrieving of the admin group"
  type = object({
    is_created  = bool
    name        = string
    description = string
    id          = string
  })
}
# ======================================================================================
# AKS
# ======================================================================================
variable "aks" {
  description = "Information about the aks"
  type = object({
    name                       = string
    version                    = string
    network_plugin             = string
    log_analytics_workspace_id = string
    default_node_pool = object({
      name       = string
      node_count = number
      vm_size    = string
    })
    automatic_channel_upgrade = string
    enable_auto_maintenance   = bool
    maintenance_window_day    = string
    maintenance_window_hour   = list(number)
  })
}

variable "aks_node_pools" {
  description = "Map of node pool to create on the aks cluster"
  type = map(object({
    enable_auto_scaling = bool
    vm_size             = string
    node_count          = number
    min_count           = number
    max_count           = number
    os_disk_type        = string
    zones               = list(string)
  }))
}


# ======================================================================================
# Network
# ======================================================================================
variable "dns_zone" {
  description = "Information about the dns zone to register the AKS"
  type = object({
    name                = string
    resource_group_name = string
  })
}

variable "aks_network" {
  description = "Information about the network of the aks"
  type = object({
    rg_name   = string
    vnet_name = string
    snet_name = string
    rt_name   = string
  })
}
