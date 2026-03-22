#!/usr/bin/env bash
# Check why init containers exited(1)
SSH_KEY="${HOME}/.ssh/cvg_neuron_proxmox"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR)

echo "=== VM454 Raster — geoserver-raster-init logs (last 30 lines) ==="
ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" ubuntu@10.10.10.203 \
  'docker logs --tail=30 geoserver-raster-init 2>&1'

echo ""
echo "=== VM455 Vector — geoserver-vector-init logs (last 30 lines) ==="
ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" ubuntu@10.10.10.204 \
  'docker logs --tail=30 geoserver-vector-init 2>&1'
