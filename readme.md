# Promote Azure Image Composite Action

This GitHub Action promotes an Azure managed image from a **CI subscription** to a **Team subscription** by:

- Creating a snapshot of the image in the CI subscription
- Granting SAS access to the snapshot
- Creating a managed disk in the Team subscription from the snapshot SAS URI
- Creating a managed image in the Team subscription from the disk
- Cleaning up snapshots and disks

---

## Inputs

| Name            | Required | Description                               | Default     |
|-----------------|----------|-------------------------------------------|-------------|
| `ci_image_name` | yes      | Name of the image in the CI subscription |             |
| `team_image_name` | yes    | Name of the image to create in Team subscription |     |
| `location`      | no       | Azure region to use (e.g. `westeurope`)  | `westeurope`|

## Secrets Required

You need two sets of Azure Service Principal credentials stored in secrets:

- **CI subscription**:
  - `CI_CLIENT_ID`
  - `CI_CLIENT_SECRET`
  - `CI_TENANT_ID`
  - `CI_SUBSCRIPTION_ID`
  - `CI_RESOURCE_GROUP`

- **Team subscription**:
  - `TEAM_CLIENT_ID`
  - `TEAM_CLIENT_SECRET`
  - `TEAM_TENANT_ID`
  - `TEAM_SUBSCRIPTION_ID`
  - `TEAM_RESOURCE_GROUP`

---

## Usage Example

```yaml
jobs:
  promote:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - name: Promote Azure Image
        uses: your-org/ci-infra/.github/actions/promote-image@main
        with:
          ci_image_name: "my-ci-image"
          team_image_name: "my-team-image"
          location: "westeurope"
        secrets:
          CI_CLIENT_ID: ${{ secrets.CI_CLIENT_ID }}
          CI_CLIENT_SECRET: ${{ secrets.CI_CLIENT_SECRET }}
          CI_TENANT_ID: ${{ secrets.CI_TENANT_ID }}
          CI_SUBSCRIPTION_ID: ${{ secrets.CI_SUBSCRIPTION_ID }}
          CI_RESOURCE_GROUP: ${{ secrets.CI_RESOURCE_GROUP }}
          TEAM_CLIENT_ID: ${{ secrets.TEAM_CLIENT_ID }}
          TEAM_CLIENT_SECRET: ${{ secrets.TEAM_CLIENT_SECRET }}
          TEAM_TENANT_ID: ${{ secrets.TEAM_TENANT_ID }}
          TEAM_SUBSCRIPTION_ID: ${{ secrets.TEAM_SUBSCRIPTION_ID }}
          TEAM_RESOURCE_GROUP: ${{ secrets.TEAM_RESOURCE_GROUP }}



Notes
Ensure the service principals have appropriate RBAC roles:

In the CI subscription, permissions to read images and manage snapshots.

In the Team subscription, permissions to create managed disks and images.

SAS token is valid for 1 hour (3600 seconds).

Cleanup deletes snapshots and intermediate disks after image creation.
