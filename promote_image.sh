#!/bin/bash
set -e

# Inputs
CI_CLIENT_ID=$1
CI_CLIENT_SECRET=$2
CI_TENANT_ID=$3
CI_SUBSCRIPTION_ID=$4
CI_RESOURCE_GROUP=$5
CI_IMAGE_NAME=$6

TEAM_CLIENT_ID=$7
TEAM_CLIENT_SECRET=$8
TEAM_TENANT_ID=$9
TEAM_SUBSCRIPTION_ID=${10}
TEAM_RESOURCE_GROUP=${11}
TEAM_IMAGE_NAME=${12}
LOCATION=${13:-westeurope}

# ==== STEP 1: Login as CI SP ====
echo "🔐 Logging in as CI SP..."
az login --service-principal \
  --username "$CI_CLIENT_ID" \
  --password "$CI_CLIENT_SECRET" \
  --tenant "$CI_TENANT_ID" > /dev/null

az account set --subscription "$CI_SUBSCRIPTION_ID"

# ==== STEP 2: Get OS disk from image ====
echo "📦 Getting OS disk from image: $CI_IMAGE_NAME"
OS_DISK_ID=$(az image show \
  --name "$CI_IMAGE_NAME" \
  --resource-group "$CI_RESOURCE_GROUP" \
  --query "storageProfile.osDisk.managedDisk.id" \
  -o tsv)

# ==== STEP 3: Create snapshot ====
SNAP_NAME="snap-${CI_IMAGE_NAME}-$(date +%s)"
echo "📸 Creating snapshot: $SNAP_NAME"
az snapshot create \
  --name "$SNAP_NAME" \
  --resource-group "$CI_RESOURCE_GROUP" \
  --source "$OS_DISK_ID" \
  --location "$LOCATION"

# ==== STEP 4: Grant access to snapshot ====
echo "🔑 Granting access to snapshot (1 hour)..."
SAS_URL=$(az snapshot grant-access \
  --name "$SNAP_NAME" \
  --resource-group "$CI_RESOURCE_GROUP" \
  --duration-in-seconds 3600 \
  --query "accessSas" -o tsv)

# ==== STEP 5: Login as Team SP ====
echo "🔐 Switching to Team SP..."
az logout
az login --service-principal \
  --username "$TEAM_CLIENT_ID" \
  --password "$TEAM_CLIENT_SECRET" \
  --tenant "$TEAM_TENANT_ID" > /dev/null

az account set --subscription "$TEAM_SUBSCRIPTION_ID"

# ==== STEP 6: Create managed disk from SAS ====
DISK_NAME="disk-${TEAM_IMAGE_NAME}-$(date +%s)"
echo "💿 Creating disk from SAS..."
az disk create \
  --name "$DISK_NAME" \
  --resource-group "$TEAM_RESOURCE_GROUP" \
  --location "$LOCATION" \
  --source "$SAS_URL"

# ==== STEP 7: Create managed image from disk ====
echo "🖼️ Creating image: $TEAM_IMAGE_NAME"
az image create \
  --name "$TEAM_IMAGE_NAME" \
  --resource-group "$TEAM_RESOURCE_GROUP" \
  --location "$LOCATION" \
  --os-type Linux \
  --source "$DISK_NAME"

# ==== STEP 8: Clean up snapshot ====
echo "🧹 Logging back in to CI SP to clean up snapshot..."
az logout
az login --service-principal \
  --username "$CI_CLIENT_ID" \
  --password "$CI_CLIENT_SECRET" \
  --tenant "$CI_TENANT_ID" > /dev/null

az account set --subscription "$CI_SUBSCRIPTION_ID"

echo "🗑️ Deleting snapshot: $SNAP_NAME"
az snapshot delete \
  --name "$SNAP_NAME" \
  --resource-group "$CI_RESOURCE_GROUP"

# Final logout
az logout
echo "✅ Promotion completed and snapshot cleaned up."
