#!/usr/bin/env bash
# Check Caddyfile content + API endpoints on all 5 VMs
K="$HOME/.ssh/cvg_neuron_proxmox"
O="-o StrictHostKeyChecking=no -o ConnectTimeout=10"

echo "============================================"
echo "VM454 — Caddyfile global block + API test"
echo "============================================"
ssh -i "$K" $O ubuntu@10.10.10.203 '
  echo "-- Caddyfile global block --"
  head -20 /opt/cvg/CVG_Geoserver_Raster/caddy/Caddyfile
  echo "-- GeoServer WMS via docker exec --"
  docker exec geoserver-raster curl -sf -o /dev/null -w "HTTP:%{http_code}" "http://localhost:8080/geoserver/ows?service=WMS&version=1.3.0&request=GetCapabilities" 2>/dev/null || echo "HTTP:ERROR"
  echo ""
  echo "-- WFS charset --"
  docker exec geoserver-raster curl -s "http://localhost:8080/geoserver/ows?service=WFS&version=2.0.0&request=GetCapabilities" 2>/dev/null | grep -i "charset" | head -1 || echo "(no charset line)"
'

echo
echo "============================================"
echo "VM455 — Caddyfile global block + API test"
echo "============================================"
ssh -i "$K" $O ubuntu@10.10.10.204 '
  echo "-- Caddyfile global block --"
  head -20 /opt/cvg/CVG_Geoserver_Vector/caddy/Caddyfile
  echo "-- GeoServer WMS via docker exec --"
  docker exec geoserver-vector curl -sf -o /dev/null -w "HTTP:%{http_code}" "http://localhost:8080/geoserver/ows?service=WMS&version=1.3.0&request=GetCapabilities" 2>/dev/null || echo "HTTP:ERROR"
  echo ""
  echo "-- WFS charset --"
  docker exec geoserver-vector curl -s "http://localhost:8080/geoserver/ows?service=WFS&version=2.0.0&request=GetCapabilities" 2>/dev/null | grep -i "charset" | head -1 || echo "(no charset line)"
'

echo
echo "============================================"
echo "VM451 — ssw-api port probe"
echo "============================================"
ssh -i "$K" $O ubuntu@10.10.10.200 '
  echo "-- ssw-api port probe --"
  docker exec ssw-api curl -sf -o /dev/null -w "HTTP:%{http_code}" http://localhost:8080/ 2>/dev/null || echo "HTTP:ERROR:8080"
  echo ""
  docker exec ssw-api curl -sf -o /dev/null -w "HTTP:%{http_code}" http://localhost:8080/health 2>/dev/null || echo "HTTP:ERROR:8080/health"
  echo ""
  docker exec ssw-api curl -sf -o /dev/null -w "HTTP:%{http_code}" http://localhost:8000/ 2>/dev/null || echo "HTTP:ERROR:8000"
  echo ""
  echo "-- ssw-api listening port --"
  docker exec ssw-api sh -c "ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null" | grep -v "^$" | head -10
'

echo
echo "============================================"
echo "VM452 — rfw-api port probe + Caddyfile"
echo "============================================"
ssh -i "$K" $O ubuntu@10.10.10.201 '
  echo "-- Caddyfile global block --"
  head -20 /opt/cvg/CVG_Rainfall_Wizard/caddy/Caddyfile
  echo "-- rfw-api port probe --"
  docker exec rfw-api curl -sf -o /dev/null -w "HTTP:%{http_code}" http://localhost:8002/ 2>/dev/null || echo "HTTP:ERROR:8002"
  echo ""
  docker exec rfw-api curl -sf -o /dev/null -w "HTTP:%{http_code}" http://localhost:8002/health 2>/dev/null || echo "HTTP:ERROR:8002/health"
  echo ""
  echo "-- rfw-api listening ports --"
  docker exec rfw-api sh -c "ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null" | head -10
'

echo
echo "============================================"
echo "VM453 — slrw-api port probe + Caddyfile"
echo "============================================"
ssh -i "$K" $O ubuntu@10.10.10.202 '
  echo "-- Caddyfile global block --"
  head -20 /opt/cvg/CVG_SLR_Wizard/caddy/Caddyfile
  echo "-- slrw-api port probe --"
  docker exec slrw-api curl -sf -o /dev/null -w "HTTP:%{http_code}" http://localhost:8010/ 2>/dev/null || echo "HTTP:ERROR:8010"
  echo ""
  docker exec slrw-api curl -sf -o /dev/null -w "HTTP:%{http_code}" http://localhost:8010/health 2>/dev/null || echo "HTTP:ERROR:8010/health"
  echo ""
  echo "-- slrw-api listening ports --"
  docker exec slrw-api sh -c "ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null" | head -10
'
