# 🚀 Azure Managed Image Transfer Across Subscriptions

This project provides a Bash script to **copy a managed image** from one Azure subscription (Subscription A) to another (Subscription B) using two different **Service Principals (SPA and SPB)**.

---

## 🧭 Overview

The process is as follows:

1. Authenticate with SPA (for Subscription A).
2. Export the managed image as a VHD to a storage account.
3. Generate a SAS URL for the VHD.
4. Authenticate with SPB (for Subscription B).
5. Create a new managed image from the SAS URL.
6. (Optional) Clean up the temporary VHD.

---

## 📁 Files

- `copy-azure-image.sh`: Main Bash script for the transfer process.
- `README.md`: This documentation.

---

## 🔧 Prerequisites

- Azure CLI installed
- Bash shell (Linux/macOS or WSL)
- Two Service Principals with the following roles:
  - **SPA (Subscription A)**:
    - `Contributor` on the Resource Group/Image
    - `Storage Blob Data Contributor` on the storage account
  - **SPB (Subscription B)**:
    - `Contributor` on the target Resource Group

---

## 🔐 Required Variables

Edit the script (`copy-azure-image.sh`) and replace the placeholders:

### Subscription A (Source)

| Variable              | Description                                |
|-----------------------|--------------------------------------------|
| `SPA_CLIENT_ID`       | App ID of SPA                              |
| `SPA_CLIENT_SECRET`   | Secret for SPA                             |
| `SUBSCRIPTION_A_ID`   | Subscription A ID                          |
| `SOURCE_RG`           | Resource group of the source image         |
| `IMAGE_NAME`          | Name of the image to export                |
| `STORAGE_ACCOUNT`     | Storage account to export the image        |
| `CONTAINER_NAME`      | Blob container name (default: `vhds`)      |

### Subscription B (Destination)

| Variable              | Description                                |
|-----------------------|--------------------------------------------|
| `SPB_CLIENT_ID`       | App ID of SPB                              |
| `SPB_CLIENT_SECRET`   | Secret for SPB                             |
| `SUBSCRIPTION_B_ID`   | Subscription B ID                          |
| `DESTINATION_RG`      | Resource group to create the new image     |
| `NEW_IMAGE_NAME`      | Name for the new image                     |
| `OS_TYPE`             | `Linux` or `Windows`                       |

---

## 🚀 How to Use

### 1. Edit the Script

```bash
nano copy-azure-image.sh
