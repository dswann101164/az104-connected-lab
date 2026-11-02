# AZ-104 Connected Lab — Build Plan

Clean Terraform build of a hub-and-spoke AZ-104 lab. `..\export` is a read-only
reference (aztfexport of the old `rg-az104-lab`); no code is copied from it.

- **Region:** East US 2 (`eastus2`)
- **Naming:** `rg-`, `vnet-`, `snet-`, `nsg-`, `pe-`, `bas-`, `st` (storage allows no dashes)
- **Resource group:** `rg-az104-connected`, fresh (decided 2026-11-02). The old
  `rg-az104-lab` is left alone for now; it is removed in the cleanup step below,
  after layer 1 is applied and only on explicit approval.
- **State:** local for now; moves to a remote backend (storage account) in layer 6
- **Rule:** each layer gets `terraform plan` reviewed before any `apply`

## Address plan

| VNet | Range | Subnets |
|---|---|---|
| `vnet-hub` | 10.10.0.0/16 | `AzureBastionSubnet` 10.10.0.0/26, `snet-pe` 10.10.1.0/24 (private endpoints) |
| `vnet-spoke-web` | 10.20.0.0/16 | `snet-web` 10.20.1.0/24 |
| `vnet-spoke-db` | 10.30.0.0/16 | `snet-db` 10.30.1.0/24 |

None of these overlap the old lab's 10.0.0.0/16.

## Layers (in build order)

### 1. Network
- Hub VNet with Azure Bastion, **Basic SKU** (decided 2026-11-02), in an
  `AzureBastionSubnet` (/26) with a Standard static public IP
- Two spoke VNets (web, db)
- Peering both ways: hub ↔ spoke-web, hub ↔ spoke-db
- An NSG on every subnet, including `AzureBastionSubnet` (which needs Microsoft's
  required Bastion rule set or Bastion will fail)
- Storage account with a blob private endpoint in the hub, and the
  `privatelink.blob.core.windows.net` private DNS zone linked to all three VNets

### 2. Governance and cost
- Tags on everything (a `tags` variable is wired in from layer 1; layer 2 enforces it)
- Budget on the resource group with alert thresholds
- Azure Policy assignments (e.g. require tags, allowed locations)

### 3. Identity
- User-assigned managed identity
- Conditional Access and PIM (Entra ID; needs P2 licensing, so this may be partly manual)

### 4. Compute
- Web VM (spoke-web) and DB VM (spoke-db) behind a load balancer
- Defender for Cloud

### 5. Monitoring
- Log Analytics workspace
- KQL alert rules
- Logic App notifications

### 6. Pipeline
- GitHub Actions: `terraform plan` → manual approval → `terraform apply`
- Remote state backend and OIDC federated credentials for the workflow

## Cleanup (last, after layer 1 is applied)

1. List everything that would be deleted: resource group `rg-az104-lab` and its
   contents, plus Connection Monitor `cm-vm-to-blob` in `NetworkWatcherRG`.
2. Wait for an explicit yes before deleting anything.
3. Never delete `NetworkWatcherRG` or `NetworkWatcher_eastus2`.
4. Keep the local `..\export` folder.

## Closed issues

- ~~Bastion Developer cannot cross peering.~~ **Closed 2026-11-02:** switched to
  Basic SKU, which reaches VMs in peered spokes.
