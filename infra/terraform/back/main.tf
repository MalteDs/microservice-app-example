data "terraform_remote_state" "infra" {
  backend = "local"
  config = {
    path = "../infrastructure/terraform.tfstate"
  }
}

# ============================
# Users API (EXTERNO)
# ============================
resource "azurerm_container_app" "users_api" {
  name                         = "users-api"
  resource_group_name          = data.terraform_remote_state.infra.outputs.resource_group_name
  container_app_environment_id = data.terraform_remote_state.infra.outputs.container_app_env_id
  revision_mode                = "Single"

  secret {
    name  = "acr-password"
    value = data.terraform_remote_state.infra.outputs.acr_admin_password
  }

  template {
    min_replicas = 1
    max_replicas = 3

    container {
      name   = "users-api"
      image  = "${data.terraform_remote_state.infra.outputs.acr_login_server}/users-api:latest"
      cpu    = 0.5
      memory = "1.0Gi"

      env { 
        name  = "JWT_SECRET"  
        value = "supersecret" 
      }
      env { 
        name  = "REDIS_HOST"  
        value = "redis"
      }
      env { 
        name  = "REDIS_PORT"  
        value = "6379" 
      }
      env {
        name  = "ZIPKIN_URL"
        value = "http://zipkin:9411/api/v2/spans"
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8083
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  registry {
    server               = data.terraform_remote_state.infra.outputs.acr_login_server
    username             = data.terraform_remote_state.infra.outputs.acr_admin_username
    password_secret_name = "acr-password"
  }
}

# ============================
# Auth API (EXTERNO)
# ============================
resource "azurerm_container_app" "auth_api" {
  name                         = "auth-api"
  resource_group_name          = data.terraform_remote_state.infra.outputs.resource_group_name
  container_app_environment_id = data.terraform_remote_state.infra.outputs.container_app_env_id
  revision_mode                = "Single"

  secret {
    name  = "acr-password"
    value = data.terraform_remote_state.infra.outputs.acr_admin_password
  }

  template {
    min_replicas = 1
    max_replicas = 3

    container {
      name   = "auth-api"
      image  = "${data.terraform_remote_state.infra.outputs.acr_login_server}/auth-api:latest"
      cpu    = 0.5
      memory = "1.0Gi"

      env { 
        name  = "JWT_SECRET"        
        value = "supersecret" 
      }
      env { 
        name  = "REDIS_HOST"        
        value = "redis"
      }
      env { 
        name  = "AUTH_API_PORT"     
        value = "8080" 
      }
      env { 
        name  = "USERS_API_ADDRESS" 
        value = "http://users-api:8083"
      }
      env {
        name  = "ZIPKIN_URL"
        value = "http://zipkin:9411/api/v2/spans"
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  registry {
    server               = data.terraform_remote_state.infra.outputs.acr_login_server
    username             = data.terraform_remote_state.infra.outputs.acr_admin_username
    password_secret_name = "acr-password"
  }

  depends_on = [azurerm_container_app.users_api]
}

# ============================
# Todos API (EXTERNO)
# ============================
resource "azurerm_container_app" "todos_api" {
  name                         = "todos-api"
  resource_group_name          = data.terraform_remote_state.infra.outputs.resource_group_name
  container_app_environment_id = data.terraform_remote_state.infra.outputs.container_app_env_id
  revision_mode                = "Single"

  secret {
    name  = "acr-password"
    value = data.terraform_remote_state.infra.outputs.acr_admin_password
  }

  template {
    min_replicas = 1
    max_replicas = 3

    container {
      name   = "todos-api"
      image  = "${data.terraform_remote_state.infra.outputs.acr_login_server}/todos-api:latest"
      cpu    = 0.5
      memory = "1.0Gi"

      env { 
        name  = "JWT_SECRET" 
        value = "supersecret" 
      }
      env { 
        name  = "REDIS_HOST" 
        value = "redis"
      }
      env {
        name  = "ZIPKIN_URL"
        value = "http://zipkin:9411/api/v2/spans"
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8082
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  registry {
    server               = data.terraform_remote_state.infra.outputs.acr_login_server
    username             = data.terraform_remote_state.infra.outputs.acr_admin_username
    password_secret_name = "acr-password"
  }
}

# ============================
# Log Processor (interno)
# ============================
resource "azurerm_container_app" "log_processor" {
  name                         = "log-processor"
  resource_group_name          = data.terraform_remote_state.infra.outputs.resource_group_name
  container_app_environment_id = data.terraform_remote_state.infra.outputs.container_app_env_id
  revision_mode                = "Single"

  secret {
    name  = "acr-password"
    value = data.terraform_remote_state.infra.outputs.acr_admin_password
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "log-processor"
      image  = "${data.terraform_remote_state.infra.outputs.acr_login_server}/log-processor:latest"
      cpu    = 0.5
      memory = "1.0Gi"

      env { 
        name  = "REDIS_HOST"    
        value = "redis"
      }
      env { 
        name  = "REDIS_PORT"    
        value = "6379" 
      }
      env { 
        name  = "REDIS_CHANNEL" 
        value = "log_channel"
      }
    }
  }

  ingress {
    external_enabled = false
    target_port      = 8081
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  registry {
    server               = data.terraform_remote_state.infra.outputs.acr_login_server
    username             = data.terraform_remote_state.infra.outputs.acr_admin_username
    password_secret_name = "acr-password"
  }
}

# ============================
# Redis (interno)
# ============================
resource "azurerm_container_app" "redis" {
  name                         = "redis"
  resource_group_name          = data.terraform_remote_state.infra.outputs.resource_group_name
  container_app_environment_id = data.terraform_remote_state.infra.outputs.container_app_env_id
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "redis"
      image  = "redis:7-alpine"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  ingress {
    external_enabled = false
    target_port      = 6379
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

# ============================
# Zipkin (interno)
# ============================
resource "azurerm_container_app" "zipkin" {
  name                         = "zipkin"
  resource_group_name          = data.terraform_remote_state.infra.outputs.resource_group_name
  container_app_environment_id = data.terraform_remote_state.infra.outputs.container_app_env_id
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "zipkin"
      image  = "openzipkin/zipkin:latest"
      cpu    = 0.5
      memory = "1.0Gi"
    }
    
  }

  ingress {
    external_enabled = false
    target_port      = 9411
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

# ============================
# Frontend (público)
# ============================
resource "azurerm_container_app" "frontend" {
  name                         = "frontend"
  resource_group_name          = data.terraform_remote_state.infra.outputs.resource_group_name
  container_app_environment_id = data.terraform_remote_state.infra.outputs.container_app_env_id
  revision_mode                = "Single"

  secret {
    name  = "acr-password"
    value = data.terraform_remote_state.infra.outputs.acr_admin_password
  }

  template {
    min_replicas = 1
    max_replicas = 5

    container {
      name   = "frontend"
      image  = "${data.terraform_remote_state.infra.outputs.acr_login_server}/frontend:latest"
      cpu    = 0.5
      memory = "1.0Gi"

      env { 
        name  = "AUTH_API_URL"  
        value = "https://${azurerm_container_app.auth_api.ingress[0].fqdn}"
      }
      env { 
        name  = "USERS_API_URL" 
        value = "https://${azurerm_container_app.users_api.ingress[0].fqdn}"
      }
      env { 
        name  = "TODOS_API_URL" 
        value = "https://${azurerm_container_app.todos_api.ingress[0].fqdn}"
      }
      # Zipkin solo accesible internamente
      env {
        name  = "ZIPKIN_URL"
        value = "http://zipkin:9411/api/v2/spans"
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 80
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  registry {
    server               = data.terraform_remote_state.infra.outputs.acr_login_server
    username             = data.terraform_remote_state.infra.outputs.acr_admin_username
    password_secret_name = "acr-password"
  }

  depends_on = [
    azurerm_container_app.auth_api,
    azurerm_container_app.users_api,
    azurerm_container_app.todos_api,
    azurerm_container_app.zipkin
  ]
}


# ============================
# Outputs
# ============================
output "frontend_url" {
  value       = "https://${azurerm_container_app.frontend.ingress[0].fqdn}"
  description = "URL del frontend"
}

output "auth_api_url" {
  value       = "https://${azurerm_container_app.auth_api.ingress[0].fqdn}"
  description = "URL del Auth API"
}

output "users_api_url" {
  value       = "https://${azurerm_container_app.users_api.ingress[0].fqdn}"
  description = "URL del Users API"
}

output "todos_api_url" {
  value       = "https://${azurerm_container_app.todos_api.ingress[0].fqdn}"
  description = "URL del Todos API"
}
