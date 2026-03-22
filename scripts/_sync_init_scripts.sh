#!/usr/bin/env bash
# Sync updated geoserver-init.sh to both VMs and write sentinel so
# future `docker compose up` won't re-run init on already-configured instances.
SSH_KEY="${HOME}/.ssh/cvg_neuron_proxmox"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR)
SCP_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR)

RASTER_IP="10.10.10.203"
VECTOR_IP="10.10.10.204"
RASTER_DEPLOY="/opt/cvg/CVG_Geoserver_Raster"
VECTOR_DEPLOY="/opt/cvg/CVG_Geoserver_Vector"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ==============================================================================
echo ""
echo "=== VM454 (Raster) — Sync geoserver-init.sh + write sentinel ==="
# Sync updated Raster init script
scp "${SCP_OPTS[@]}" -i "${SSH_KEY}" \
  "${SCRIPT_DIR}/scripts/geoserver-init.sh" \
  "ubuntu@${RASTER_IP}:${RASTER_DEPLOY}/scripts/geoserver-init.sh"
echo "  Raster geoserver-init.sh synced"

# Write sentinel so next compose up skips init (already configured manually)
ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" ubuntu@${RASTER_IP} bash << 'REMOTE'
SENTINEL="/opt/geoserver/data_dir/.cvg_init_done"

# Write sentinel via docker exec (runs as geoserver user who owns data_dir)
if docker exec geoserver-raster test -f "${SENTINEL}" 2>/dev/null; then
  echo "  Sentinel already exists — no action needed"
else
  docker exec geoserver-raster touch "${SENTINEL}"
  echo "  Sentinel created: ${SENTINEL}"
fi

# Verify
docker exec geoserver-raster test -f "${SENTINEL}" && echo "  Sentinel OK" || echo "  ERROR: sentinel not found"

# Show current init script version (first few lines of step 6 section)
echo ""
echo "  Init script Step 6 section (tail):"
tail -20 /opt/cvg/CVG_Geoserver_Raster/scripts/geoserver-init.sh
REMOTE

# ==============================================================================
echo ""
echo "=== VM455 (Vector) — Sync geoserver-init.sh + write sentinel ==="
scp "${SCP_OPTS[@]}" -i "${SSH_KEY}" \
  "${SCRIPT_DIR}/../CVG_Geoserver_Vector/scripts/geoserver-init.sh" \
  "ubuntu@${VECTOR_IP}:${VECTOR_DEPLOY}/scripts/geoserver-init.sh"
echo "  Vector geoserver-init.sh synced"

ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" ubuntu@${VECTOR_IP} bash << 'REMOTE'
SENTINEL="/opt/geoserver/data_dir/.cvg_init_done"

if docker exec geoserver-vector test -f "${SENTINEL}" 2>/dev/null; then
  echo "  Sentinel already exists — no action needed"
else
  docker exec geoserver-vector touch "${SENTINEL}"
  echo "  Sentinel created: ${SENTINEL}"
fi

docker exec geoserver-vector test -f "${SENTINEL}" && echo "  Sentinel OK" || echo "  ERROR: sentinel not found"

echo ""
echo "  Init script Step 6 section (tail):"
tail -20 /opt/cvg/CVG_Geoserver_Vector/scripts/geoserver-init.sh
REMOTE

echo ""
echo "Done. Future 'docker compose up' runs will skip init (sentinel exists)."
echo "If re-initialization is needed, delete the sentinel first:"
echo "  docker exec geoserver-raster rm /opt/geoserver/data_dir/.cvg_init_done"
echo "  docker exec geoserver-vector rm /opt/geoserver/data_dir/.cvg_init_done"
