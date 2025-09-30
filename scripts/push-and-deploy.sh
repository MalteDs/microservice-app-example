#!/usr/bin/env bash
set -euo pipefail

# --- Configuración ---
SUBSCRIPTION_ID="4b6f9b0e-c22f-4d47-b6fb-465fde5d1ab5"
RESOURCE_GROUP="rg-ingesoft"
ACR_LOGIN_SERVER="acringesoftmicroserviceapp.azurecr.io"
ACR_NAME="acringesoftmicroserviceapp" # parte antes de .azurecr.io
TAG="latest"

# --- Asegurarse de estar autenticado ---
echo "🔐 Haciendo login en Azure y ACR..."
az account set --subscription "$SUBSCRIPTION_ID"
az acr login --name "$ACR_NAME"

# --- Construir imágenes locales ---
echo "⚙️  Construyendo imágenes locales..."
sudo docker build -t microservice-app-example-frontend:latest ./frontend
sudo docker build -t microservice-app-example-auth-api:latest ./auth-api
sudo docker build -t microservice-app-example-users-api:latest ./users-api
sudo docker build -t microservice-app-example-todos-api:latest ./todos-api
sudo docker build -t microservice-app-example-log-message-processor:latest ./log-message-processor

# --- Etiquetar para ACR ---
echo "🏷️  Etiquetando imágenes para $ACR_LOGIN_SERVER ..."
sudo docker tag microservice-app-example-frontend:latest              $ACR_LOGIN_SERVER/frontend:$TAG
sudo docker tag microservice-app-example-auth-api:latest              $ACR_LOGIN_SERVER/auth-api:$TAG
sudo docker tag microservice-app-example-users-api:latest             $ACR_LOGIN_SERVER/users-api:$TAG
sudo docker tag microservice-app-example-todos-api:latest             $ACR_LOGIN_SERVER/todos-api:$TAG
sudo docker tag microservice-app-example-log-message-processor:latest $ACR_LOGIN_SERVER/log-processor:$TAG

# --- Push a ACR ---
echo "⬆️  Subiendo imágenes a ACR ..."
sudo docker push $ACR_LOGIN_SERVER/frontend:$TAG
sudo docker push $ACR_LOGIN_SERVER/auth-api:$TAG
sudo docker push $ACR_LOGIN_SERVER/users-api:$TAG
sudo docker push $ACR_LOGIN_SERVER/todos-api:$TAG
sudo docker push $ACR_LOGIN_SERVER/log-processor:$TAG

# --- Actualizar Container Apps en Azure ---
echo "🔄 Actualizando Container Apps para que usen las nuevas imágenes..."
az containerapp update --name frontend       --resource-group "$RESOURCE_GROUP" --image $ACR_LOGIN_SERVER/frontend:$TAG
az containerapp update --name auth-api       --resource-group "$RESOURCE_GROUP" --image $ACR_LOGIN_SERVER/auth-api:$TAG
az containerapp update --name users-api      --resource-group "$RESOURCE_GROUP" --image $ACR_LOGIN_SERVER/users-api:$TAG
az containerapp update --name todos-api      --resource-group "$RESOURCE_GROUP" --image $ACR_LOGIN_SERVER/todos-api:$TAG
az containerapp update --name log-processor  --resource-group "$RESOURCE_GROUP" --image $ACR_LOGIN_SERVER/log-processor:$TAG

# --- Opcional: forzar revisión de Redis y Zipkin (imágenes públicas, no push) ---
# az containerapp update --name redis  --resource-group "$RESOURCE_GROUP" --image redis:7-alpine
# az containerapp update --name zipkin --resource-group "$RESOURCE_GROUP" --image openzipkin/zipkin:latest

# --- Comprobar frontend env-config.js ---
FRONTEND_FQDN=$(az containerapp show --name frontend --resource-group "$RESOURCE_GROUP" --query "properties.configuration.ingress.fqdn" -o tsv)
echo "✅ Despliegue completado. Frontend en: https://$FRONTEND_FQDN"
echo "🔎 Comprobando env-config.js..."
curl -s "https://$FRONTEND_FQDN/env-config.js" | sed -n '1,120p'
