#!/usr/bin/env bash
# Diagnose port bindings and Caddyfile locations on all 5 VMs
K="$HOME/.ssh/cvg_neuron_proxmox"
O="-o StrictHostKeyChecking=no -o ConnectTimeout=10"

for entry in "10.10.10.203:VM454" "10.10.10.204:VM455" "10.10.10.200:VM451" "10.10.10.201:VM452" "10.10.10.202:VM453"; do
  IP="${entry%%:*}"
  LABEL="${entry##*:}"
  echo
  echo "=== $LABEL ($IP) ==="
  ssh -i "$K" $O ubuntu@"$IP" \
    'echo "-- docker ps --"; docker ps --format "{{.Names}} | {{.Ports}}"; echo "-- Caddyfile paths --"; find /opt -name Caddyfile 2>/dev/null'
done
