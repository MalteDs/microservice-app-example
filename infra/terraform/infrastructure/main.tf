# infra/terraform/infrastructure/main.tf
# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-ingesoft"
  location = "eastus"
}

# Azure Container Registry (ACR) - cambia el nombre si no es único
resource "azurerm_container_registry" "acr" {
  name                = "acrIngesoftMicroserviceApp"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Container Apps Environment (CAE)
resource "azurerm_container_app_environment" "cae" {
  name                = "cae-ingesoft"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# ----------------------
# Outputs
# ----------------------
output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "location" {
  value = azurerm_resource_group.rg.location
}

output "acr_name" {
  value = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "acr_admin_username" {
  value     = azurerm_container_registry.acr.admin_username
  sensitive = true
}

output "acr_admin_password" {
  value     = azurerm_container_registry.acr.admin_password
  sensitive = true
}

# NEW: nombre del Container Apps Environment (útil para formar FQDNs)
output "container_app_env_name" {
  value = azurerm_container_app_environment.cae.name
}

# Existing ID (si lo necesitas)
output "container_app_env_id" {
  value = azurerm_container_app_environment.cae.id
}
