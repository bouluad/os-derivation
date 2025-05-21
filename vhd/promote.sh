#!/bin/bash

# ========== Configuration ==========
# SPA credentials (Subscription A)
SPA_CLIENT_ID="<SPA_CLIENT_ID>"
SPA_CLIENT_SECRET="<SPA_CLIENT_SECRET>"
TENANT_ID="<TENANT_ID>"
SUBSCRIPTION_A_ID="<SUBSCRIPTION_A_ID>"

# SPB credentials (Subscription B)
SPB_CLIENT_ID="<SPB_CLIENT_ID>"
SPB_CLIENT_SECRET="<SPB_CLIENT_SECRET>"
SUBSCRIPTION_B_ID="<SUBSCRIPTION_B_ID>"

# Image details
SOURCE_RG="<SOURCE_IMAGE_RG>"
IMAGE_NAME="<SOURCE_IMAGE_NAME>"
DESTINATION_RG="<DEST_IMAGE_RG>"
NEW_IMAGE_NAME="<NEW_IMAGE_NAME>"
OS_TYPE="Linux" # or "Windows"

# Storage details (in Subscription A)
STORAGE_ACCOUNT="<STORAGE_ACCOUNT_NAME>"
CONTAINER_NAME="vhds"
VHD_NAME="${IMAGE_NAME}.vhd"

# SAS expiry (2 hours from now)
SAS_EXPIRY=$(date -u -d "2 hours" '+%Y-%m-%dT%H:%MZ')

# ========== Step 1: Login as SPA ==========
echo "Logging in as SPA..."
az login --service-principal \
  --username "$SPA_CLIENT_ID" \
  --password "$SPA_CLIENT_SECRET" \
  --tenant "$TENANT_ID" >/dev/null

az account set --subscription "$SUBSCRIPTION_A_ID"

# ========== Step 2: Export Image to VHD ==========
echo "Exporting image to VHD..."
az image export \
  --resource-group "$SOURCE_RG" \
  --name "$IMAGE_NAME" \
  --storage-account "$STORAGE_ACCOUNT" \
  --container-name "$CONTAINER_NAME" \
  --output-name "$VHD_NAME"

# ========== Step 3: Generate SAS URL ==========
echo "Generating SAS URL for VHD..."
SAS_TOKEN=$(az storage blob generate-sas \
  --account-name "$STORAGE_ACCOUNT" \
  --container-name "$CONTAINER_NAME" \
  --name "$VHD_NAME" \
  --permissions r \
  --expiry "$SAS_EXPIRY" \
  --output tsv)

VHD_URL="https://${STORAGE_ACCOUNT}.blob.core.windows.net/${CONTAINER_NAME}/${VHD_NAME}?${SAS_TOKEN}"

# ========== Step 4: Login as SPB ==========
echo "Logging in as SPB..."
az login --service-principal \
  --username "$SPB_CLIENT_ID" \
  --password "$SPB_CLIENT_SECRET" \
  --tenant "$TENANT_ID" >/dev/null

az account set --subscription "$SUBSCRIPTION_B_ID"

# ========== Step 5: Create Managed Image from VHD ==========
echo "Creating image in Subscription B..."
az image create \
  --resource-group "$DESTINATION_RG" \
  --name "$NEW_IMAGE_NAME" \
  --os-type "$OS_TYPE" \
  --source "$VHD_URL"

# ========== Optional: Cleanup VHD ==========
echo "Cleaning up VHD in source storage..."
az login --service-principal \
  --username "$SPA_CLIENT_ID" \
  --password "$SPA_CLIENT_SECRET" \
  --tenant "$TENANT_ID" >/dev/null

az account set --subscription "$SUBSCRIPTION_A_ID"

az storage blob delete \
  --account-name "$STORAGE_ACCOUNT" \
  --container-name "$CONTAINER_NAME" \
  --name "$VHD_NAME"

echo "✅ Image transfer complete."
