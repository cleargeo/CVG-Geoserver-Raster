#!/usr/bin/env bash
# Run geoserver-init profile on BOTH VMs (Raster + Vector) sequentially.
# Pre-requisite: admin password must be reset to 'geoserver' on both VMs.
SSH_KEY="${HOME}/.ssh/cvg_neuron_proxmox"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -o LogLevel=ERROR)

run_init() {
  local label="$1" ip="$2" dir="$3"
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  Running geoserver-init — ${label} (${ip})"
  echo "═══════════════════════════════════════════════════════"
  ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" "ubuntu@${ip}" bash << REMOTE
set -euo pipefail
cd "${dir}"
echo "[+] Removing any stale init container..."
docker rm -f geoserver-raster-init geoserver-vector-init 2>/dev/null || true
echo "[+] Starting geoserver-init profile..."
docker compose -f docker-compose.prod.yml --profile init \
  up --abort-on-container-exit --remove-orphans geoserver-init
EXIT=\$?
echo "[+] geoserver-init finished — exit code: \${EXIT}"
REMOTE
}

# ── Run Raster first, then Vector ─────────────────────────────────────────────
run_init "VM454 RASTER" "10.10.10.203" "/opt/cvg/CVG_Geoserver_Raster"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Raster init complete — starting Vector..."
echo "═══════════════════════════════════════════════════════"

run_init "VM455 VECTOR" "10.10.10.204" "/opt/cvg/CVG_Geoserver_Vector"

echo ""
echo "All done."
