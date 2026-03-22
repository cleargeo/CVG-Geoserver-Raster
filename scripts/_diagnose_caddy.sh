#!/usr/bin/env bash
# Deep-diagnose Caddy TLS state + verify current Caddyfile config
SSH_KEY="${HOME}/.ssh/cvg_neuron_proxmox"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR)

diag_vm() {
  local label="$1" ip="$2" caddy_ctr="$3"
  echo ""
  echo "=== ${label} (${ip}) ==="

  ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" "ubuntu@${ip}" bash -s -- "$caddy_ctr" << 'REMOTE'
CTR="$1"

echo "[1] Caddy container inspect..."
docker inspect "$CTR" --format '  Status: {{.State.Status}}  Restarts: {{.RestartCount}}'

echo ""
echo "[2] Caddy data dir contents..."
docker exec "$CTR" find /data/caddy -maxdepth 4 2>/dev/null || echo "  /data/caddy not found"

echo ""
echo "[3] Caddy config dir contents..."
docker exec "$CTR" find /config/caddy -maxdepth 4 2>/dev/null || echo "  /config/caddy not found"

echo ""
echo "[4] Current Caddyfile..."
cat /opt/cvg/CVG_Geoserver_*/Caddyfile 2>/dev/null || \
  docker exec "$CTR" cat /etc/caddy/Caddyfile 2>/dev/null || \
  echo "  Caddyfile not found via cat"

echo ""
echo "[5] Caddy recent logs (last 30 lines)..."
docker logs "$CTR" --tail=30 2>&1

echo ""
echo "[6] Test HTTPS on localhost (verbose TLS)..."
curl -vsk --connect-timeout 5 https://localhost/status 2>&1 | head -30

echo ""
echo "[7] Caddy admin API..."
curl -sf --connect-timeout 5 http://localhost:2019/ 2>/dev/null && echo "  Admin API OK" || echo "  Admin API not reachable"
curl -sf --connect-timeout 5 http://localhost:2019/config/ 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print('  Config keys:', list(d.keys()))" 2>/dev/null || true
REMOTE
}

diag_vm "VM454 Raster" "10.10.10.203" "caddy-gsr"
diag_vm "VM455 Vector" "10.10.10.204" "caddy-gsv"
