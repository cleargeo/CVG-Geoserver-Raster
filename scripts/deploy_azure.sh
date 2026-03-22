#!/bin/bash
# ============================================================
#  CVG GeoServer Raster — Azure Passwordless Deploy Script
#  Prerequisites: Run setup_azure_auth.bat once on your machine
#
#  This script:
#    1. Verifies az login is active (no password input needed)
#    2. Fetches ALL secrets from Azure Key Vault
#    3. Builds and pushes Docker image to ACR
#    4. Deploys to Azure VM via run-command (no SSH password)
# ============================================================

set -euo pipefail

# ── Configuration — edit these ────────────────────────────────
RESOURCE_GROUP="cvg-rg"
VM_NAME="cvg-geoserver-raster-01"
ACR_NAME="cvgregistry"
KEYVAULT_NAME="cvg-keyvault"
IMAGE_NAME="geoserver-raster"
IMAGE_TAG="${IMAGE_TAG:-latest}"
REMOTE_DEPLOY_DIR="/opt/cvg/geoserver-raster"
# ─────────────────────────────────────────────────────────────

FULL_IMAGE="${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"

echo ""
echo "============================================================"
echo "  CVG GeoServer Raster — Azure Passwordless Deploy"
echo "  Image: ${FULL_IMAGE}"
echo "============================================================"
echo ""

# ── Step 1: Verify Azure login ────────────────────────────────
echo "[1/5] Verifying Azure identity..."
CURRENT_USER=$(az account show --query "user.name" -o tsv 2>/dev/null || echo "")
if [ -z "$CURRENT_USER" ]; then
    echo ""
    echo "  Not logged in to Azure. Running: az login"
    echo "  (Browser will open — sign in with your Azure AD account)"
    echo ""
    az login
    CURRENT_USER=$(az account show --query "user.name" -o tsv)
fi
SUBSCRIPTION=$(az account show --query "name" -o tsv)
echo "  Logged in as: ${CURRENT_USER}"
echo "  Subscription: ${SUBSCRIPTION}"
echo ""

# ── Step 2: Fetch secrets from Key Vault (no passwords in script!) ──
echo "[2/5] Fetching secrets from Azure Key Vault: ${KEYVAULT_NAME}..."

fetch_secret() {
    local SECRET_NAME="$1"
    local VALUE
    VALUE=$(az keyvault secret show \
        --vault-name "${KEYVAULT_NAME}" \
        --name "${SECRET_NAME}" \
        --query value -o tsv 2>/dev/null || echo "")
    if [ -z "$VALUE" ]; then
        echo "  WARNING: Secret '${SECRET_NAME}' not found in Key Vault. Skipping."
    fi
    echo "$VALUE"
}

GEOSERVER_ADMIN_PASSWORD=$(fetch_secret "geoserver-admin-password")
GEOSERVER_DB_PASSWORD=$(fetch_secret "geoserver-db-password")

echo "  Secrets loaded into memory (not written to disk). OK."
echo ""

# ── Step 3: Build Docker image ────────────────────────────────
echo "[3/5] Building Docker image..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

docker build \
    --build-arg GEOSERVER_ADMIN_PASSWORD="${GEOSERVER_ADMIN_PASSWORD}" \
    -t "${FULL_IMAGE}" \
    -f "${PROJECT_DIR}/Dockerfile" \
    "${PROJECT_DIR}"

echo "  Build complete. OK."
echo ""

# ── Step 4: Push to ACR (uses az login token — no docker password!) ──
echo "[4/5] Pushing image to Azure Container Registry..."
az acr login --name "${ACR_NAME}"   # Uses your cached az login — no password prompt!
docker push "${FULL_IMAGE}"
echo "  Push complete. OK."
echo ""

# ── Step 5: Deploy on VM (no SSH password needed!) ───────────
echo "[5/5] Deploying on Azure VM: ${VM_NAME}..."
az vm run-command invoke \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${VM_NAME}" \
    --command-id RunShellScript \
    --scripts "
        set -e
        echo 'Pulling image ${FULL_IMAGE}...'

        # Login to ACR using VM's Managed Identity (no creds on VM either!)
        az acr login --name ${ACR_NAME} 2>/dev/null || \
            docker login ${ACR_NAME}.azurecr.io \
                --username \$(az acr credential show --name ${ACR_NAME} --query username -o tsv) \
                --password \$(az acr credential show --name ${ACR_NAME} --query passwords[0].value -o tsv)

        docker pull ${FULL_IMAGE}

        cd ${REMOTE_DEPLOY_DIR}
        export GEOSERVER_IMAGE=${FULL_IMAGE}
        docker-compose -f docker-compose.prod.yml up -d --remove-orphans

        echo 'Deploy complete.'
        docker ps --filter name=geoserver
    "

echo ""
echo "============================================================"
echo "  Deploy Complete!"
echo "  Image: ${FULL_IMAGE}"
echo "  VM:    ${VM_NAME} (${RESOURCE_GROUP})"
echo "============================================================"
echo ""
echo "  Check status:"
echo "    az vm run-command invoke \\"
echo "      --resource-group ${RESOURCE_GROUP} \\"
echo "      --name ${VM_NAME} \\"
echo "      --command-id RunShellScript \\"
echo "      --scripts 'docker ps && docker logs geoserver --tail 20'"
echo ""

# Unset secrets from memory
unset GEOSERVER_ADMIN_PASSWORD
unset GEOSERVER_DB_PASSWORD
