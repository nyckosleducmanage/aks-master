output "ad_application" {
  value = azuread_application.aks_sp.application_id
}

output "service_principal_id" {
  value = azuread_service_principal.aks_sp.id
}

output "service_principal_password" {
  value = azuread_service_principal_password.aks_sp_pwd.value
}

output "aks_node_resource_group" {
  value = azurerm_kubernetes_cluster.aks.node_resource_group
}