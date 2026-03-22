#!/usr/bin/env bash
# Diagnose why geoserver-init can't reach the REST API on VM454
SSH_KEY="${HOME}/.ssh/cvg_neuron_proxmox"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR)

echo "═══════════════════════════════════════════════════════"
echo "  Diagnosing geoserver-init REST API on VM454 (10.10.10.203)"
echo "═══════════════════════════════════════════════════════"
ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" ubuntu@10.10.10.203 bash << 'REMOTE'

echo ""
echo "=== 1. Docker networks ==="
docker network ls

echo ""
echo "=== 2. Which network is geoserver-raster on? ==="
docker inspect geoserver-raster --format '{{range $k,$v := .NetworkSettings.Networks}}  Network: {{$k}} | IP: {{$v.IPAddress}}{{println}}{{end}}'

echo ""
echo "=== 3. Which network is geoserver-raster-init on? ==="
docker inspect geoserver-raster-init --format '{{range $k,$v := .NetworkSettings.Networks}}  Network: {{$k}} | IP: {{$v.IPAddress}}{{println}}{{end}}' 2>/dev/null || echo "  (init container may have already exited)"

echo ""
echo "=== 4. Test REST API from INSIDE geoserver-raster container ==="
docker exec geoserver-raster curl -fsS -u admin:geoserver \
  --max-time 8 \
  "http://localhost:8080/geoserver/rest/about/version.json" \
  -o /dev/null -w "HTTP %{http_code}\n" 2>&1 || echo "  FAILED"

echo ""
echo "=== 5. Test REST API verbose from geoserver-raster (check auth) ==="
docker exec geoserver-raster curl -sS -u admin:geoserver \
  --max-time 8 \
  "http://localhost:8080/geoserver/rest/about/version.json" \
  -w "\nHTTP %{http_code}\n" 2>&1 | head -20

echo ""
echo "=== 6. Test REST /rest/workspaces from inside container ==="
docker exec geoserver-raster curl -sS -u admin:geoserver \
  --max-time 8 \
  "http://localhost:8080/geoserver/rest/workspaces.json" \
  -w "\nHTTP %{http_code}\n" 2>&1 | head -10

echo ""
echo "=== 7. Check GeoServer REST API config (any IP restrictions?) ==="
docker exec geoserver-raster find /opt/geoserver/data_dir \
  -name "security" -type d 2>/dev/null | head -5
docker exec geoserver-raster cat /opt/geoserver/data_dir/security/rest.properties 2>/dev/null \
  || echo "  (no rest.properties found)"

echo ""
echo "=== 8. Recent GeoServer logs (last 30 lines) ==="
docker logs geoserver-raster --tail 30 2>&1

echo ""
echo "=== 9. Sentinel file status ==="
docker exec geoserver-raster ls -la /opt/geoserver/data_dir/.cvg_init_done 2>/dev/null \
  || echo "  Sentinel not found (init not yet completed)"

REMOTE
echo ""
echo "Done."
