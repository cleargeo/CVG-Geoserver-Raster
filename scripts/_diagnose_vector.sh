#!/usr/bin/env bash
# Diagnose + fix VM455 GeoServer Vector stack

SSH_KEY="${HOME}/.ssh/cvg_neuron_proxmox"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR)
VECTOR_IP="10.10.10.204"

echo ""
echo "══════════════════════════════════════════════════"
echo "  DIAGNOSIS: VM455 GeoServer Vector"
echo "══════════════════════════════════════════════════"
ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" "ubuntu@${VECTOR_IP}" bash << 'REMOTE'
echo "--- All containers (including stopped) ---"
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "--- docker compose stack state ---"
cd /opt/cvg/CVG_Geoserver_Vector 2>/dev/null || { echo "PROJECT DIR NOT FOUND"; exit 1; }
docker compose -f docker-compose.prod.yml ps 2>/dev/null || echo "compose ps failed"

echo ""
echo "--- Disk space on VM ---"
df -h /

echo ""
echo "--- geoserver-vector last 30 log lines ---"
docker logs geoserver-vector 2>&1 | tail -30 || echo "(container not found)"

echo ""
echo "--- caddy-gsv last 20 log lines ---"
docker logs caddy-gsv 2>&1 | tail -20 || echo "(caddy-gsv not found)"

echo ""
echo "--- docker image list ---"
docker images | grep -E "cvg|geoserver|caddy|watchtower"

echo ""
echo "--- docker system df ---"
docker system df
REMOTE
