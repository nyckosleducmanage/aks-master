data "azuread_client_config" "current" {}

# ======================================================================================
# Resource Group
# ======================================================================================
data "azurerm_resource_group" "resource_group" {
  name = var.resource_group_name
}

# ======================================================================================
# Network
# ======================================================================================
# Retrieve the private_dns_zone that will be used by the AKS
data "azurerm_private_dns_zone" "dns_zone" {
  provider = azurerm.servicespartages

  name                = var.dns_zone.name
  resource_group_name = var.dns_zone.resource_group_name
}

# Retrieve the vnet used to deploy the AKS
data "azurerm_virtual_network" "aks_vnet" {
  name                = var.aks_network.vnet_name
  resource_group_name = var.aks_network.rg_name
}

# Retrieve the subnet used to deploy the AKS
data "azurerm_subnet" "aks_subnet" {
  name                 = var.aks_network.snet_name
  virtual_network_name = var.aks_network.vnet_name
  resource_group_name  = var.aks_network.rg_name
}

# Retrieve Route Table of the subnet used to deploy the AKS
data "azurerm_route_table" "aks_rt" {
  name                = var.aks_network.rt_name
  resource_group_name = var.aks_network.rg_name
}

# ======================================================================================
# Active Directory Group
# ======================================================================================

# Create admin group if doesn't exist
resource "azuread_group" "aks_aad_clusteradmins" {
  count = var.aks_admin_group.is_created ? 0 : 1

  display_name     = var.aks_admin_group.name
  description      = var.aks_admin_group.description
  security_enabled = true

  lifecycle {
    ignore_changes = [members]
  }
}

# Get the CLOUD_G2S_ADMIN_DATALAB group
data "azuread_group" "cloud_admin" {
  object_id        = "f1ccbb49-fb4d-49c3-81a1-a578b06f9586"
  security_enabled = true
}

# ======================================================================================
# Register Active Directory Application
# ======================================================================================

# Creation of the service principal for AKS
resource "azuread_application" "aks_sp" {
  display_name = "${var.aks.name}-ServicePrincipal"
  owners       = data.azuread_group.cloud_admin.members

  web {
    implicit_grant {
      access_token_issuance_enabled = false
    }
  }
}

resource "azuread_service_principal" "aks_sp" {
  application_id = azuread_application.aks_sp.application_id
}

resource "azuread_service_principal_password" "aks_sp_pwd" {
  service_principal_id = azuread_service_principal.aks_sp.object_id
}

# ======================================================================================
# Service Principal Role Association
# ======================================================================================

# Give right to contribute on the private DNS Zone
resource "azurerm_role_assignment" "aks_sp_role_dns" {
  scope                = data.azurerm_private_dns_zone.dns_zone.id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azuread_service_principal.aks_sp.id
}


# Give right to contribute on the vnet
resource "azurerm_role_assignment" "aks_sp_role_vnet" {
  scope                = data.azurerm_virtual_network.aks_vnet.id
  role_definition_name = "Network Contributor"
  principal_id         = azuread_service_principal.aks_sp.id
}

# Give right to contribute on the route table associated to the subnet
resource "azurerm_role_assignment" "aks_sp_role_rt" {
  scope                = data.azurerm_route_table.aks_rt.id
  role_definition_name = "Network Contributor"
  principal_id         = azuread_service_principal.aks_sp.id
}

# ======================================================================================
# Cluster Creation
# ======================================================================================

# Creation of the Azure Kubernetes Service (AKS)
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks.name
  location            = data.azurerm_resource_group.resource_group.location
  resource_group_name = var.resource_group_name

  dns_prefix                = var.aks.name
  private_dns_zone_id       = data.azurerm_private_dns_zone.dns_zone.id
  kubernetes_version        = var.aks.version
  automatic_channel_upgrade = var.aks.automatic_channel_upgrade

  default_node_pool {
    name                         = var.aks.default_node_pool.name
    node_count                   = var.aks.default_node_pool.node_count
    vm_size                      = var.aks.default_node_pool.vm_size
    type                         = "VirtualMachineScaleSets"
    vnet_subnet_id               = data.azurerm_subnet.aks_subnet.id
    os_disk_type                 = "Ephemeral"
    only_critical_addons_enabled = true
    tags                         = var.tags
    zones           = ["1", "2", "3"]
  }

  dynamic "maintenance_window" {
    for_each = var.aks.enable_auto_maintenance ? [1] : []
    content {
      allowed {
        day   = var.aks.maintenance_window_day
        hours = var.aks.maintenance_window_hour
      }
    }
  }

  network_profile {
    load_balancer_sku = "standard"
    network_plugin    = var.aks.network_plugin
    outbound_type     = "userDefinedRouting"
  }

  service_principal {
    client_id     = azuread_service_principal.aks_sp.application_id
    client_secret = azuread_service_principal_password.aks_sp_pwd.value
  }

  private_cluster_enabled = true

  azure_active_directory_role_based_access_control  {
    managed                = true
    admin_group_object_ids = var.aks_admin_group.is_created ? [var.aks_admin_group.id] : [azuread_group.aks_aad_clusteradmins[0].id]
    azure_rbac_enabled = true
  }

  azure_policy_enabled = true

  oms_agent {
    log_analytics_workspace_id = var.aks.log_analytics_workspace_id
  }

  tags = var.tags

  depends_on = [
    azurerm_role_assignment.aks_sp_role_dns,
    azurerm_role_assignment.aks_sp_role_vnet
  ]
}

# Creation of users node pool
resource "azurerm_kubernetes_cluster_node_pool" "user_node_pools" {
  for_each = var.aks_node_pools

  name                  = each.key
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  enable_auto_scaling   = each.value.enable_auto_scaling
  vm_size               = each.value.vm_size
  node_count            = each.value.node_count
  min_count             = each.value.min_count
  max_count             = each.value.max_count
  os_disk_type          = each.value.os_disk_type
  vnet_subnet_id        = data.azurerm_subnet.aks_subnet.id
  zones                 = each.value.zones

  tags = var.tags

}


# ======================================================================================
# AKS Role Assignment
# ======================================================================================
resource "azurerm_role_assignment" "aks_sp_role_admin_rg" {
  scope                = data.azurerm_resource_group.resource_group.id
  role_definition_name = "Azure Kubernetes Service Cluster Admin Role"
  principal_id         = azuread_service_principal.aks_sp.id
}

resource "azurerm_role_assignment" "aks_sp_role_contributor_rg" {
  scope                = data.azurerm_resource_group.resource_group.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.aks_sp.id
}
