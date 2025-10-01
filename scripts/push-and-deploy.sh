#!/usr/bin/env bash
set -euo pipefail

# --- Configuración ---
SUBSCRIPTION_ID="4b6f9b0e-c22f-4d47-b6fb-465fde5d1ab5"
RESOURCE_GROUP="rg-ingesoft"
ACR_LOGIN_SERVER="acringesoftmicroserviceapp.azurecr.io"
ACR_NAME="acringesoftmicroserviceapp"

# --- Generar tag único ---
TAG=$(git rev-parse --short HEAD || date +%Y%m%d%H%M%S)

# --- Login ---
echo "🔐 Login en Azure..."
az account set --subscription "$SUBSCRIPTION_ID"
az acr login --name "$ACR_NAME"

# --- Build ---
echo "⚙️  Construyendo imágenes..."
docker build -t frontend:$TAG       ./frontend
docker build -t auth-api:$TAG       ./auth-api
docker build -t users-api:$TAG      ./users-api
docker build -t todos-api:$TAG      ./todos-api
docker build -t log-processor:$TAG  ./log-message-processor

# --- Tag para ACR ---
docker tag frontend:$TAG       $ACR_LOGIN_SERVER/frontend:$TAG
docker tag auth-api:$TAG       $ACR_LOGIN_SERVER/auth-api:$TAG
docker tag users-api:$TAG      $ACR_LOGIN_SERVER/users-api:$TAG
docker tag todos-api:$TAG      $ACR_LOGIN_SERVER/todos-api:$TAG
docker tag log-processor:$TAG  $ACR_LOGIN_SERVER/log-processor:$TAG

# --- Push ---
docker push $ACR_LOGIN_SERVER/frontend:$TAG
docker push $ACR_LOGIN_SERVER/auth-api:$TAG
docker push $ACR_LOGIN_SERVER/users-api:$TAG
docker push $ACR_LOGIN_SERVER/todos-api:$TAG
docker push $ACR_LOGIN_SERVER/log-processor:$TAG

# --- Actualizar tfvars ---
cat > ../infra/terraform/back/terraform.tfvars <<EOF
frontend_tag      = "$TAG"
auth_api_tag      = "$TAG"
users_api_tag     = "$TAG"
todos_api_tag     = "$TAG"
log_processor_tag = "$TAG"
EOF

# --- Aplicar Terraform ---
terraform apply -auto-approve
