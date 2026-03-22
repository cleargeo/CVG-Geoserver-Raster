# Azure Authentication Strategy — CVG GeoServer
*Zero-Password Management Approach*

**Date:** 2026-03-22  
**Author:** Alex Zelenski / Cline  
**Scope:** CVG GeoServer Raster & Vector — Azure connectivity without tracking passwords

---

## Key Vault Firewall — Change Log

| Date | Action | Vault | IP |
|------|--------|-------|----|
| 2026-03-22 | ❌ Removed | `cvg-keyvault-01`, `cvg-esc-sync-kv` | `108.188.217.225` — DeLand office (closed) |
| 2026-03-22 | ❌ Removed | `cvg-keyvault-01`, `cvg-esc-sync-kv` | `97.104.40.25` — DeLand office (closed) |
| 2026-03-22 | ✅ Added | `cvg-keyvault-01`, `cvg-esc-sync-kv` | `131.148.52.225` — New Smyrna Beach office |

**Current authorized office IP:** `131.148.52.225` (New Smyrna Beach)  
**To update IP in future** (one command per vault — just change the IP):
```bash
# Remove old IP
az keyvault network-rule remove --name cvg-keyvault-01 --ip-address "OLD.IP.HERE/32"
az keyvault network-rule remove --name cvg-esc-sync-kv --ip-address "OLD.IP.HERE/32"
# Add new IP  
az keyvault network-rule add --name cvg-keyvault-01 --ip-address "NEW.IP.HERE/32"
az keyvault network-rule add --name cvg-esc-sync-kv --ip-address "NEW.IP.HERE/32"
```

---

## Executive Summary

Your current setup uses on-prem Proxmox VMs with **four credentials hardcoded in plaintext** inside `deploy_production.sh`:

| Variable | What it is | Risk |
|----------|-----------|------|
| `CI_PASS` | VM cloud-init password (`CVGadmin2026!`) | In git history |
| `SMB_PASS` | TrueNAS CIFS password (`CVGproc1!2026`) | In git history |
| `PVE_TOKEN` | Proxmox API token with full root access | In git history — rotate immediately |
| `GEOSERVER_ADMIN_PASSWORD` | Loaded from `.env` (gitignored) | ✅ Already handled correctly |

Azure Key Vault solves this: store secrets there once, scripts fetch them at runtime — nothing hardcoded anywhere. Since your VMs are **on-prem Proxmox today** (not Azure VMs), the strategy uses `az login` + Key Vault only — Managed Identity is the path when/if you provision Azure VMs.

When moving to Azure, you can eliminate ALL password management using a layered identity strategy:

| Layer | Method | Zero-Password? |
|-------|--------|---------------|
| Your Windows dev machine → Azure | `az login` (browser) | ✅ One-time, auto-refreshes |
| Azure VM → Other Azure services | Managed Identity | ✅ No creds ever |
| GitHub Actions → Azure | Workload Identity Federation | ✅ No secrets in GitHub |
| SSH into Azure VMs | Azure AD SSH / Key Vault SSH keys | ✅ No passwords |
| App secrets (GeoServer admin pass, etc.) | Azure Key Vault | ✅ Rotate in one place |

---

## The Three Environments & Their Auth Needs

```
┌─────────────────────────┐     ┌──────────────────────┐     ┌─────────────────────┐
│  YOUR WINDOWS MACHINE   │────▶│   AZURE CONTROL      │────▶│   AZURE VMs         │
│  (dev/deploy)           │     │   PLANE              │     │   (GeoServer)       │
│                         │     │                      │     │                     │
│  az login (browser)     │     │  Azure AD / Entra    │     │  Managed Identity   │
│  → token cached         │     │  RBAC                │     │  → auto-auth to     │
│  → auto-refreshes       │     │                      │     │    ACR, Key Vault   │
└─────────────────────────┘     └──────────────────────┘     └─────────────────────┘
```

---

## Method 1: `az login` for Your Windows Dev Machine ⭐ START HERE

This is the **single best thing you can do right now**. One browser login, tokens are cached and auto-refreshed. No passwords anywhere in scripts.

### How It Works
- You run `az login` once in a terminal
- Browser opens → you log in with your Azure AD (Microsoft) account  
- A token is cached at `~/.azure/` (encrypted by Windows DPAPI)
- Token refreshes automatically — you may need to re-login every few days/weeks depending on your tenant's Conditional Access policy
- ALL `az` CLI commands in scripts automatically use this token

### Setup (One-Time)
```cmd
REM Install Azure CLI if not already installed
winget install Microsoft.AzureCLI

REM Login once — browser opens
az login

REM Set your default subscription (so you never need --subscription in scripts)
az account set --subscription "YOUR-SUBSCRIPTION-NAME-OR-ID"

REM Verify
az account show
```

### In Your Scripts (No Passwords!)
```bash
# deploy_production.sh — Azure version
# NO passwords, NO tokens — just use az CLI which is already authenticated

# Push Docker image to ACR
az acr login --name cvgregistry   # uses your cached az login token

# SSH to Azure VM using AAD
az ssh vm --resource-group cvg-rg --vm-name cvg-geoserver-raster-01

# Run commands on VM
az vm run-command invoke \
  --resource-group cvg-rg \
  --name cvg-geoserver-raster-01 \
  --command-id RunShellScript \
  --scripts "docker pull cvgregistry.azurecr.io/geoserver:latest && docker-compose up -d"
```

### Pros/Cons
| ✅ Pros | ❌ Cons |
|---------|---------|
| Zero password management | Requires re-login periodically |
| Works today with existing Azure account | Interactive (browser) — not headless |
| Tokens auto-refresh | Need `az login` on each new machine |
| Nothing to rotate or store | |

---

## Method 2: Managed Identity for Azure VMs ⭐ CRITICAL FOR VMs

When your GeoServer runs **on an Azure VM**, that VM can have a **Managed Identity** — an Azure AD identity that Azure manages automatically. The VM can pull from ACR, read Key Vault secrets, etc. **without any credentials**.

### Setup
```bash
# 1. Enable System-Assigned Managed Identity on your VM
az vm identity assign \
  --resource-group cvg-rg \
  --name cvg-geoserver-raster-01

# 2. Get the VM's principal ID
PRINCIPAL_ID=$(az vm show \
  --resource-group cvg-rg \
  --name cvg-geoserver-raster-01 \
  --query identity.principalId -o tsv)

# 3. Grant the VM's identity permission to pull from ACR
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role AcrPull \
  --scope $(az acr show --name cvgregistry --query id -o tsv)

# 4. Grant the VM's identity permission to read Key Vault secrets
az keyvault set-policy \
  --name cvg-keyvault-01 \
  --object-id $PRINCIPAL_ID \
  --secret-permissions get list
```

### How VM Code Uses It (No Passwords!)
```bash
# On the Azure VM — get an ACR token automatically
az acr login --name cvgregistry   # uses the VM's Managed Identity, no login needed!

# Or in Python (no credentials in code)
from azure.identity import ManagedIdentityCredential
from azure.keyvault.secrets import SecretClient

credential = ManagedIdentityCredential()
client = SecretClient(vault_url="https://cvg-keyvault-01.vault.azure.net/", credential=credential)
geoserver_password = client.get_secret("geoserver-admin-password").value
```

---

## Method 3: Azure Key Vault — The Password Cemetery 🔐

**Stop putting passwords in `.env` files and deploy scripts.** Put them ALL in Azure Key Vault. Update in one place. Apps fetch them automatically.

### ⚠️ Immediate Action Required
The Proxmox API token (`PVE_TOKEN=PVEAPIToken=root@pam!fulltoken=...`) is hardcoded in `deploy_production.sh` **and is in your git history**. Rotate it immediately in Proxmox (Datacenter → API Tokens) before migrating it to Key Vault.

### What Goes In Key Vault (mapped to actual `deploy_production.sh` variables)
```
cvg-keyvault-01/
├── geoserver-admin-password   ← GEOSERVER_ADMIN_PASSWORD (currently in .env — already safe)
├── proxmox-vm-cipassword      ← CI_PASS="CVGadmin2026!"  (currently hardcoded — migrate this)
├── truenas-smb-password       ← SMB_PASS="CVGproc1!2026" (currently hardcoded — migrate this)
├── truenas-smb-username       ← SMB_USER="ProcessingVM1" (not secret, but centralizes it)
├── proxmox-api-token          ← PVE_TOKEN (ROTATE FIRST, then store here)
└── cvg-ssh-private-key        ← ~/.ssh/cvg_neuron_proxmox contents (for disaster recovery)
```

### Setup Key Vault
```bash
# Key Vault already exists: cvg-keyvault-01 (CVG-KeyVault-RG)
# Store a secret (one-time, or when you need to change it)
az keyvault secret set \
  --vault-name cvg-keyvault-01 \
  --name geoserver-admin-password \
  --value "your-super-secret-password"

# From now on, never hardcode this password anywhere
# Scripts fetch it:
GEOSERVER_PASS=$(az keyvault secret show \
  --vault-name cvg-keyvault-01 \
  --name geoserver-admin-password \
  --query value -o tsv)
```

### In Your Deploy Scripts
```bash
#!/bin/bash
# deploy_production.sh — PASSWORDLESS version

# Fetch all secrets from Key Vault (uses your az login token — no passwords!)
echo "Fetching secrets from Azure Key Vault..."
GEOSERVER_ADMIN_PASS=$(az keyvault secret show --vault-name cvg-keyvault-01 --name geoserver-admin-password --query value -o tsv)
NAS_PASS=$(az keyvault secret show --vault-name cvg-keyvault-01 --name nas-cifs-password --query value -o tsv)

# Use them temporarily in memory — never written to disk
export GEOSERVER_ADMIN_PASSWORD="$GEOSERVER_ADMIN_PASS"

# Deploy
docker-compose -f docker-compose.prod.yml up -d

# Unset after use
unset GEOSERVER_ADMIN_PASSWORD
```

---

## Method 4: SSH to Azure VMs Without Passwords 🔑

Replace SSH password auth with one of two approaches:

### Option A: Azure AD SSH (Best — Zero Key Management)
```bash
# One-time VM setup
az extension add --name ssh   # Install az ssh extension

# Enable AAD login on the VM
az vm extension set \
  --resource-group cvg-rg \
  --vm-name cvg-geoserver-raster-01 \
  --name AADSSHLoginForLinux \
  --publisher Microsoft.Azure.ActiveDirectory

# Assign "Virtual Machine Administrator Login" role to yourself
az role assignment create \
  --resource-group cvg-rg \
  --assignee your-email@domain.com \
  --role "Virtual Machine Administrator Login"

# SSH in — uses your az login token, NO password, NO private key files!
az ssh vm \
  --resource-group cvg-rg \
  --name cvg-geoserver-raster-01
```

### Option B: SSH Keys (Classic — Better than passwords)
```bash
# Generate SSH key (one-time, store private key safely)
ssh-keygen -t ed25519 -C "cvg-geoserver-deploy" -f ~/.ssh/cvg_geoserver_ed25519

# Add public key to VM
az vm user update \
  --resource-group cvg-rg \
  --name cvg-geoserver-raster-01 \
  --username azureuser \
  --ssh-key-value "$(cat ~/.ssh/cvg_geoserver_ed25519.pub)"

# SSH in (no password prompt)
ssh -i ~/.ssh/cvg_geoserver_ed25519 azureuser@<vm-public-ip>

# Store the PRIVATE KEY in Key Vault for safekeeping
az keyvault secret set \
  --vault-name cvg-keyvault-01 \
  --name cvg-geoserver-ssh-private-key \
  --file ~/.ssh/cvg_geoserver_ed25519
```

---

## Method 5: Workload Identity Federation for GitHub Actions ⭐ FOR CI/CD

**Never** put `AZURE_CLIENT_SECRET` in GitHub repository secrets. Use OIDC federation instead — GitHub proves its identity to Azure with a signed JWT, **zero secrets exchanged**.

### Setup (One-Time)
```bash
# 1. Create a Service Principal (app registration)
az ad app create --display-name "cvg-geoserver-github-actions"
APP_ID=$(az ad app list --display-name "cvg-geoserver-github-actions" --query [0].appId -o tsv)

# 2. Create the Service Principal
az ad sp create --id $APP_ID
SP_OBJECT_ID=$(az ad sp show --id $APP_ID --query id -o tsv)

# 3. Add Federated Credential for GitHub Actions (NO SECRET CREATED)
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "cvg-geoserver-github",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:azelenski_cvg/CVG-Geoserver-Vector:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# 4. Grant the SP permissions (e.g., AcrPush, VM Contributor)
az role assignment create \
  --assignee $APP_ID \
  --role Contributor \
  --resource-group cvg-rg

# 5. Note these values for GitHub secrets (NOT passwords — just IDs)
echo "AZURE_CLIENT_ID: $APP_ID"
echo "AZURE_TENANT_ID: $(az account show --query tenantId -o tsv)"
echo "AZURE_SUBSCRIPTION_ID: $(az account show --query id -o tsv)"
```

### GitHub Actions Workflow (No Secrets!)
```yaml
# .github/workflows/deploy.yml
name: Deploy GeoServer

on:
  push:
    branches: [main]

permissions:
  id-token: write   # Required for OIDC
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Azure Login (OIDC — no passwords!)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}       # NOT a password
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}       # NOT a password
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}  # NOT a password

      - name: Push to ACR
        run: |
          az acr login --name cvgregistry
          docker build -t cvgregistry.azurecr.io/geoserver:latest .
          docker push cvgregistry.azurecr.io/geoserver:latest

      - name: Deploy to VM
        run: |
          az vm run-command invoke \
            --resource-group cvg-rg \
            --name cvg-geoserver-raster-01 \
            --command-id RunShellScript \
            --scripts "cd /opt/geoserver && docker-compose pull && docker-compose up -d"
```

---

## Recommended Implementation Order

```
PHASE 1 — Do This Week (15 minutes)
────────────────────────────────────
1. Run `az login` on your Windows machine
2. Run setup_azure_auth.bat (provided below)
   → Creates Resource Group, Key Vault
3. Migrate all hardcoded passwords to Key Vault
4. Update deploy scripts to fetch from Key Vault

PHASE 2 — When You Create Azure VMs (30 minutes)
──────────────────────────────────────────────────
5. Enable Managed Identity on each VM
6. Grant VM identity: AcrPull + Key Vault read
7. Enable AAD SSH login on VMs
8. Retire all SSH password auth

PHASE 3 — When You Set Up GitHub Actions (20 minutes)
───────────────────────────────────────────────────────
9. Create Federated Credential (no client secret)
10. Add AZURE_CLIENT_ID, TENANT_ID, SUBSCRIPTION_ID to GitHub Secrets
11. Use azure/login OIDC action in workflow
```

---

## What You Will NEVER Have to Track Again

| Old Way | New Way |
|---------|---------|
| GeoServer admin password in `.env` | Azure Key Vault → update once |
| SSH password for VMs | `az ssh vm` or SSH key |
| Docker registry password | `az acr login` (uses your Azure login) |
| Proxmox API tokens in scripts | Key Vault secret |
| GitHub Actions `AZURE_CLIENT_SECRET` | OIDC Federation (no secret!) |
| NAS CIFS password in deploy scripts | Key Vault secret |

**Total passwords to manage after migration: 0**  
*You only maintain your one Azure AD account login.*

---

## Quick Reference Commands

```bash
# Authenticate (one-time per machine)
az login

# Fetch a secret (works after az login)
az keyvault secret show --vault-name cvg-keyvault-01 --name geoserver-admin-password --query value -o tsv

# SSH to Azure VM without password
az ssh vm --resource-group cvg-rg --vm-name cvg-geoserver-raster-01

# Push Docker image to ACR without docker login password
az acr login --name cvgregistry
docker push cvgregistry.azurecr.io/geoserver:latest

# Check your current Azure identity
az account show
az ad signed-in-user show
```

---

## See Also
- `scripts/setup_azure_auth.bat` — Automated one-time Azure setup script
- `scripts/deploy_azure.sh` — Passwordless deploy script template
- Azure Docs: [Managed Identities](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/)
- Azure Docs: [Key Vault](https://learn.microsoft.com/azure/key-vault/)
- Azure Docs: [Workload Identity Federation](https://learn.microsoft.com/azure/active-directory/develop/workload-identity-federation)
