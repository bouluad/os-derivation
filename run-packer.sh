#!/bin/bash

# Configuration
RESOURCE_GROUP="my-image-rg"
IMAGE_NAME="packer-image"
LOCATION="westeurope"

# Run packer build
packer build \
  -var "client_id=$AZURE_CLIENT_ID" \
  -var "client_secret=$AZURE_CLIENT_SECRET" \
  -var "tenant_id=$AZURE_TENANT_ID" \
  -var "subscription_id=$AZURE_SUBSCRIPTION_ID" \
  azure-image.json

# Show image details
echo -e "\n🔍 Azure Image Details:"
az image show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$IMAGE_NAME" \
  --output table
