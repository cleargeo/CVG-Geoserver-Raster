#!/usr/bin/env bash
SSH_KEY="${HOME}/.ssh/cvg_neuron_proxmox"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -o LogLevel=ERROR)

echo "═══════════════════════════════════════════════════════"
echo "  Running geoserver-init on VM454 — Raster (10.10.10.203)"
echo "═══════════════════════════════════════════════════════"
ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" ubuntu@10.10.10.203 bash << 'REMOTE'
set -euo pipefail
cd /opt/cvg/CVG_Geoserver_Raster
echo "[+] Starting geoserver-init profile..."
docker compose -f docker-compose.prod.yml --profile init \
  up --abort-on-container-exit --remove-orphans geoserver-init
echo "[+] geoserver-init finished — exit code: $?"
REMOTE

echo ""
echo "Done."
