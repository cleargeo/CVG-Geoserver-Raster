#!/usr/bin/env bash
# Diagnose HTTP 400 on WFS/WCS GetCapabilities after init ran
SSH_KEY="${HOME}/.ssh/cvg_neuron_proxmox"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR)

echo "═══════════════════════════════════════════════════════"
echo "  Diagnosing WFS/WCS 400 — VM454 RASTER (10.10.10.203)"
echo "═══════════════════════════════════════════════════════"
ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" ubuntu@10.10.10.203 bash << 'REMOTE'

echo ""
echo "=== 1. WFS GetCapabilities (raw response, first 20 lines) ==="
docker exec geoserver-raster curl -s --max-time 10 \
  "http://localhost:8080/geoserver/ows?service=wfs&version=2.0.0&request=GetCapabilities" \
  | head -20

echo ""
echo "=== 2. WFS with version 1.1.0 ==="
docker exec geoserver-raster curl -s -o /dev/null -w "HTTP %{http_code}\n" --max-time 10 \
  "http://localhost:8080/geoserver/ows?service=wfs&version=1.1.0&request=GetCapabilities"

echo ""
echo "=== 3. WCS GetCapabilities (raw response, first 20 lines) ==="
docker exec geoserver-raster curl -s --max-time 10 \
  "http://localhost:8080/geoserver/ows?service=wcs&version=2.0.1&request=GetCapabilities" \
  | head -20

echo ""
echo "=== 4. WFS service enabled status via REST ==="
docker exec geoserver-raster curl -sS -u admin:geoserver --max-time 10 \
  "http://localhost:8080/geoserver/rest/services/wfs/settings.json" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); \
    print('  WFS enabled:', d['wfs']['enabled'])" 2>/dev/null || echo "  (could not parse)"

echo ""
echo "=== 5. WCS service enabled status via REST ==="
docker exec geoserver-raster curl -sS -u admin:geoserver --max-time 10 \
  "http://localhost:8080/geoserver/rest/services/wcs/settings.json" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); \
    print('  WCS enabled:', d['wcs']['enabled'])" 2>/dev/null || echo "  (could not parse)"

echo ""
echo "=== 6. Recent GeoServer error logs ==="
docker logs geoserver-raster --since 10m 2>&1 | grep -i "error\|exception\|warn\|400" | tail -20

REMOTE

echo ""
echo "Done."
