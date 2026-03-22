#!/usr/bin/env bash
# Finalize geoserver-init on both VMs:
#   1. Write controlflow.properties via docker exec (geoserver user owns data_dir)
#   2. Write sentinel file via docker exec
#   3. Sync updated docker-compose.prod.yml + scripts to both VMs
#   4. Restart geoserver containers to pick up new controlflow.properties bind mount
SSH_KEY="${HOME}/.ssh/cvg_neuron_proxmox"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -o LogLevel=ERROR)

finalize_vm() {
  local label="$1" ip="$2" ctr="$3" deploy_dir="$4"
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  Finalizing — ${label} (${ip})"
  echo "═══════════════════════════════════════════════════════"
  ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" "ubuntu@${ip}" bash << REMOTE
set -euo pipefail

CTR="${ctr}"
DATA_DIR="/opt/geoserver/data_dir"
SENTINEL="\${DATA_DIR}/.cvg_init_done"
CF="\${DATA_DIR}/controlflow.properties"

echo "[+] Writing sentinel file via docker exec..."
docker exec "\${CTR}" sh -c "touch '\${SENTINEL}' && echo '  Sentinel written: \${SENTINEL}'"

echo "[+] Verifying sentinel..."
docker exec "\${CTR}" ls -la "\${SENTINEL}" && echo "  ✓ Sentinel confirmed"

echo "[+] Checking controlflow.properties..."
if docker exec "\${CTR}" test -f "\${CF}"; then
  echo "  controlflow.properties already exists (bind-mount or previous write)"
  docker exec "\${CTR}" head -3 "\${CF}"
else
  echo "  Writing controlflow.properties via docker exec..."
  docker exec "\${CTR}" sh -c 'cat > /opt/geoserver/data_dir/controlflow.properties << EOF
# CVG GeoServer rate control — written by finalize_init
ows.global=100
user.ows=25
ows.wms.getmap=30
ows.wcs.getcoverage=10
ows.wfs.getfeature=20
timeout=60
EOF'
  echo "  ✓ controlflow.properties written"
fi

REMOTE
}

# ── Finalize both VMs ─────────────────────────────────────────────────────────
finalize_vm "VM454 RASTER" "10.10.10.203" "geoserver-raster" "/opt/cvg/CVG_Geoserver_Raster"
finalize_vm "VM455 VECTOR" "10.10.10.204" "geoserver-vector" "/opt/cvg/CVG_Geoserver_Vector"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Syncing updated configs to both VMs..."
echo "═══════════════════════════════════════════════════════"

# Sync Raster
echo ""
echo "[+] Syncing Raster (VM454: 10.10.10.203)..."
rsync -avz --no-perms \
  -e "ssh ${SSH_OPTS[*]} -i ${SSH_KEY}" \
  --include="docker-compose.prod.yml" \
  --include="scripts/" \
  --include="scripts/controlflow.properties" \
  --include="scripts/geoserver-init.sh" \
  --exclude="*" \
  "$(dirname "$0")/" \
  "ubuntu@10.10.10.203:/opt/cvg/CVG_Geoserver_Raster/"

# Sync Vector
echo ""
echo "[+] Syncing Vector (VM455: 10.10.10.204)..."
VECTOR_DIR="$(dirname "$0")/../CVG_Geoserver_Vector"
rsync -avz --no-perms \
  -e "ssh ${SSH_OPTS[*]} -i ${SSH_KEY}" \
  --include="docker-compose.prod.yml" \
  --include="scripts/" \
  --include="scripts/controlflow.properties" \
  --include="scripts/geoserver-init.sh" \
  --exclude="*" \
  "${VECTOR_DIR}/" \
  "ubuntu@10.10.10.204:/opt/cvg/CVG_Geoserver_Vector/"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Applying new docker-compose (recreate geoserver only)"
echo "═══════════════════════════════════════════════════════"

for vm_info in "10.10.10.203:/opt/cvg/CVG_Geoserver_Raster:geoserver-raster" \
               "10.10.10.204:/opt/cvg/CVG_Geoserver_Vector:geoserver-vector"; do
  IFS=: read -r ip dir ctr <<< "${vm_info}"
  echo ""
  echo "[+] Recreating ${ctr} on ${ip} with new bind mount..."
  ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" "ubuntu@${ip}" bash << REMOTE
set -euo pipefail
cd "${dir}"
docker compose -f docker-compose.prod.yml up -d --no-build --force-recreate "${ctr}"
echo "  Waiting 30s for container to become healthy..."
sleep 30
docker inspect --format '{{.State.Health.Status}}' "${ctr}"
REMOTE
done

echo ""
echo "All done."
