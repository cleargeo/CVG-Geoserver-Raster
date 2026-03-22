#!/usr/bin/env bash
# Sync updated files to both VMs via scp, then recreate geoserver containers
# to apply the corrected controlflow.properties bind-mount.
SSH_KEY="${HOME}/.ssh/cvg_neuron_proxmox"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -o LogLevel=ERROR)
SCP_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "${SSH_KEY}" -o LogLevel=ERROR)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VECTOR_DIR="${SCRIPT_DIR}/../CVG_Geoserver_Vector"

scp_file() {
  local src="$1" dest_host="$2" dest_path="$3"
  scp "${SCP_OPTS[@]}" "${src}" "ubuntu@${dest_host}:${dest_path}"
}

echo "═══════════════════════════════════════════════════════"
echo "  Syncing Raster files → VM454 (10.10.10.203)"
echo "═══════════════════════════════════════════════════════"
scp_file "${SCRIPT_DIR}/docker-compose.prod.yml"       "10.10.10.203" "/opt/cvg/CVG_Geoserver_Raster/docker-compose.prod.yml"
scp_file "${SCRIPT_DIR}/scripts/geoserver-init.sh"     "10.10.10.203" "/opt/cvg/CVG_Geoserver_Raster/scripts/geoserver-init.sh"
scp_file "${SCRIPT_DIR}/scripts/controlflow.properties" "10.10.10.203" "/opt/cvg/CVG_Geoserver_Raster/scripts/controlflow.properties"
echo "  ✓ Raster files synced"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Syncing Vector files → VM455 (10.10.10.204)"
echo "═══════════════════════════════════════════════════════"
scp_file "${VECTOR_DIR}/docker-compose.prod.yml"       "10.10.10.204" "/opt/cvg/CVG_Geoserver_Vector/docker-compose.prod.yml"
scp_file "${VECTOR_DIR}/scripts/geoserver-init.sh"     "10.10.10.204" "/opt/cvg/CVG_Geoserver_Vector/scripts/geoserver-init.sh"
scp_file "${VECTOR_DIR}/scripts/controlflow.properties" "10.10.10.204" "/opt/cvg/CVG_Geoserver_Vector/scripts/controlflow.properties"
echo "  ✓ Vector files synced"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Recreating containers with updated compose (Raster)"
echo "═══════════════════════════════════════════════════════"
ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" ubuntu@10.10.10.203 bash << 'REMOTE'
set -euo pipefail
cd /opt/cvg/CVG_Geoserver_Raster
echo "[+] Recreating geoserver-raster with new bind-mount..."
docker compose -f docker-compose.prod.yml up -d --no-build --force-recreate geoserver-raster
echo "[+] Waiting 90s for healthy status..."
sleep 90
STATUS=$(docker inspect --format '{{.State.Health.Status}}' geoserver-raster)
echo "  geoserver-raster health: ${STATUS}"
echo "[+] Verifying controlflow.properties is bind-mounted..."
docker inspect geoserver-raster --format '{{range .Mounts}}{{if eq .Destination "/opt/geoserver/data_dir/controlflow.properties"}}  ✓ controlflow.properties bind-mounted from {{.Source}}{{println}}{{end}}{{end}}'
REMOTE

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Recreating containers with updated compose (Vector)"
echo "═══════════════════════════════════════════════════════"
ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" ubuntu@10.10.10.204 bash << 'REMOTE'
set -euo pipefail
cd /opt/cvg/CVG_Geoserver_Vector
echo "[+] Recreating geoserver-vector with new bind-mount..."
docker compose -f docker-compose.prod.yml up -d --no-build --force-recreate geoserver-vector
echo "[+] Waiting 90s for healthy status..."
sleep 90
STATUS=$(docker inspect --format '{{.State.Health.Status}}' geoserver-vector)
echo "  geoserver-vector health: ${STATUS}"
echo "[+] Verifying controlflow.properties is bind-mounted..."
docker inspect geoserver-vector --format '{{range .Mounts}}{{if eq .Destination "/opt/geoserver/data_dir/controlflow.properties"}}  ✓ controlflow.properties bind-mounted from {{.Source}}{{println}}{{end}}{{end}}'
REMOTE

echo ""
echo "All done."
