#!/usr/bin/env bash
# Quick status check for both GeoServer VMs — uses docker exec to reach internal port

SSH_KEY="${HOME}/.ssh/cvg_neuron_proxmox"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR)

RASTER_IP="10.10.10.203"
VECTOR_IP="10.10.10.204"

echo ""
echo "══════════════════════════════════════════════════"
echo "  VM454 — GeoServer RASTER (${RASTER_IP})"
echo "══════════════════════════════════════════════════"
ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" "ubuntu@${RASTER_IP}" bash << 'REMOTE'
echo "--- Docker containers ---"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "--- Internal GeoServer health (via docker exec) ---"
echo -n "  Web UI: "
docker exec geoserver-raster curl -sf --connect-timeout 8 -o /dev/null -w "HTTP %{http_code}\n" \
  "http://localhost:8080/geoserver/web/" 2>/dev/null || echo "NOT READY"

echo -n "  WMS GetCapabilities: "
docker exec geoserver-raster curl -sf --connect-timeout 8 -o /dev/null -w "HTTP %{http_code}\n" \
  "http://localhost:8080/geoserver/ows?service=wms&version=1.3.0&request=GetCapabilities" 2>/dev/null || echo "NOT READY"

echo -n "  WFS GetCapabilities: "
docker exec geoserver-raster curl -sf --connect-timeout 8 -o /dev/null -w "HTTP %{http_code}\n" \
  "http://localhost:8080/geoserver/ows?service=wfs&version=2.0.0&request=GetCapabilities" 2>/dev/null || echo "NOT READY"

echo ""
echo "--- Caddy (public entry point, :80) ---"
echo -n "  HTTP->HTTPS redirect: "
curl -sf --connect-timeout 8 -o /dev/null -w "HTTP %{http_code}\n" \
  "http://localhost:80/" 2>/dev/null || echo "NOT READY"
REMOTE

echo ""
echo "══════════════════════════════════════════════════"
echo "  VM455 — GeoServer VECTOR (${VECTOR_IP})"
echo "══════════════════════════════════════════════════"
ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" "ubuntu@${VECTOR_IP}" bash << 'REMOTE'
echo "--- Docker containers ---"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "--- Internal GeoServer health (via docker exec) ---"
echo -n "  Web UI: "
docker exec geoserver-vector curl -sf --connect-timeout 8 -o /dev/null -w "HTTP %{http_code}\n" \
  "http://localhost:8080/geoserver/web/" 2>/dev/null || echo "NOT READY"

echo -n "  WFS GetCapabilities: "
docker exec geoserver-vector curl -sf --connect-timeout 8 -o /dev/null -w "HTTP %{http_code}\n" \
  "http://localhost:8080/geoserver/ows?service=wfs&version=2.0.0&request=GetCapabilities" 2>/dev/null || echo "NOT READY"

echo -n "  WMS GetCapabilities: "
docker exec geoserver-vector curl -sf --connect-timeout 8 -o /dev/null -w "HTTP %{http_code}\n" \
  "http://localhost:8080/geoserver/ows?service=wms&version=1.3.0&request=GetCapabilities" 2>/dev/null || echo "NOT READY"

echo ""
echo "--- Caddy (public entry point, :80) ---"
echo -n "  HTTP->HTTPS redirect: "
curl -sf --connect-timeout 8 -o /dev/null -w "HTTP %{http_code}\n" \
  "http://localhost:80/" 2>/dev/null || echo "NOT READY"
REMOTE

echo ""
echo "Done."
