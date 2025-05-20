#!/bin/bash
set -euo pipefail

# Parameters
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

echo "==> Starting image promotion"
echo "CI Subscription: $CI_SUBSCRIPTION_ID"
echo "Team Subscription: $TEAM_SUBSCRIPTION_ID"
echo "Image to promote: $CI_IMAGE_NAME -> $TEAM_IMAGE_NAME"
echo "Location: $LOCATION"

# Login to CI subscription (where image is built)
echo "-> Logging into CI subscription"
az login --service-principal -u "$CI_CLIENT_ID" -p "$CI_CLIENT_SECRET" --tenant "$CI_TENANT_ID" > /dev/null
az account set --subscription "$CI_SUBSCRIPTION_ID"

# Get the image resource ID
IMAGE_ID=$(az image show --name "$CI_IMAGE_NAME" --resource-group "$CI_RESOURCE_GROUP" --query "id" -o tsv)
if [ -z "$IMAGE_ID" ]; then
  echo "ERROR: Image $CI_IMAGE_NAME not found in resource group $CI_RESOURCE_GROUP"
  exit 1
fi
echo "Found CI image ID: $IMAGE_ID"

# Create snapshot from image's OS disk
SNAPSHOT_NAME="${CI_IMAGE_NAME}-snapshot-$(date +%s)"
echo "-> Creating snapshot $SNAPSHOT_NAME"
az snapshot create \
  --resource-group "$CI_RESOURCE_GROUP" \
  --name "$SNAPSHOT_NAME" \
  --source "$IMAGE_ID" \
  --location "$LOCATION"

# Grant read access (SAS token) for snapshot for 1 hour (3600 seconds)
echo "-> Granting read access to snapshot for 1 hour"
SNAPSHOT_URI=$(az snapshot grant-access --resource-group "$CI_RESOURCE_GROUP" --name "$SNAPSHOT_NAME" --duration-in-seconds 3600 --query "accessSas" -o tsv)

if [ -z "$SNAPSHOT_URI" ]; then
  echo "ERROR: Failed to get SAS URI for snapshot"
  exit 1
fi
echo "Snapshot SAS URI: $SNAPSHOT_URI"

# Logout from CI subscription
az logout

# Login to Team subscription to restore snapshot and create image
echo "-> Logging into Team subscription"
az login --service-principal -u "$TEAM_CLIENT_ID" -p "$TEAM_CLIENT_SECRET" --tenant "$TEAM_TENANT_ID" > /dev/null
az account set --subscription "$TEAM_SUBSCRIPTION_ID"

# Create managed disk from snapshot SAS URI
DISK_NAME="${TEAM_IMAGE_NAME}-disk-$(date +%s)"
echo "-> Creating managed disk $DISK_NAME in team subscription from snapshot URI"
az disk create \
  --resource-group "$TEAM_RESOURCE_GROUP" \
  --name "$DISK_NAME" \
  --source "$SNAPSHOT_URI" \
  --location "$LOCATION"

# Create image from managed disk
echo "-> Creating managed image $TEAM_IMAGE_NAME in team subscription"
az image create \
  --resource-group "$TEAM_RESOURCE_GROUP" \
  --name "$TEAM_IMAGE_NAME" \
  --source "$DISK_NAME" \
  --location "$LOCATION"

# Cleanup: revoke SAS access and delete snapshot
echo "-> Revoking SAS access and deleting snapshot in CI subscription"
az logout
az login --service-principal -u "$CI_CLIENT_ID" -p "$CI_CLIENT_SECRET" --tenant "$CI_TENANT_ID" > /dev/null
az account set --subscription "$CI_SUBSCRIPTION_ID"

az snapshot revoke-access --resource-group "$CI_RESOURCE_GROUP" --name "$SNAPSHOT_NAME" || true
az snapshot delete --resource-group "$CI_RESOURCE_GROUP" --name "$SNAPSHOT_NAME" || true

# Optionally delete managed disk in team subscription after image creation
echo "-> Cleaning up managed disk $DISK_NAME in team subscription"
az logout
az login --service-principal -u "$TEAM_CLIENT_ID" -p "$TEAM_CLIENT_SECRET" --tenant "$TEAM_TENANT_ID" > /dev/null
az account set --subscription "$TEAM_SUBSCRIPTION_ID"
az disk delete --resource-group "$TEAM_RESOURCE_GROUP" --name "$DISK_NAME" --yes || true

# Final logout
az logout

echo "==> Image promotion completed successfully!"
