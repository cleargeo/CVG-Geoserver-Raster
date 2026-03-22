#!/usr/bin/env bash
SSH_KEY="${HOME}/.ssh/cvg_neuron_proxmox"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR)

echo "=== Verifying Vector charset fix ==="
ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" ubuntu@10.10.10.204 bash << 'REMOTE'
echo "[+] Checking charset in current settings..."
docker exec geoserver-vector curl -sS -u admin:geoserver --max-time 10 \
  "http://localhost:8080/geoserver/rest/settings.json" 2>/dev/null \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print('  charset =', d['global']['settings'].get('charset','NOT SET'))"

echo "[+] WFS 2.0.0 GetCapabilities..."
CODE=$(docker exec geoserver-vector curl -sS -o /dev/null -w "%{http_code}" --max-time 10 \
  "http://localhost:8080/geoserver/ows?service=wfs&version=2.0.0&request=GetCapabilities")
echo "  HTTP ${CODE}"

echo "[+] WMS 1.3.0 GetCapabilities..."
CODE=$(docker exec geoserver-vector curl -sS -o /dev/null -w "%{http_code}" --max-time 10 \
  "http://localhost:8080/geoserver/ows?service=wms&version=1.3.0&request=GetCapabilities")
echo "  HTTP ${CODE}"

echo "[+] WFS 1.1.0 GetCapabilities..."
CODE=$(docker exec geoserver-vector curl -sS -o /dev/null -w "%{http_code}" --max-time 10 \
  "http://localhost:8080/geoserver/ows?service=wfs&version=1.1.0&request=GetCapabilities")
echo "  HTTP ${CODE}"
REMOTE

echo ""
echo "=== Verifying Raster charset still holds ==="
ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" ubuntu@10.10.10.203 bash << 'REMOTE'
docker exec geoserver-raster curl -sS -u admin:geoserver --max-time 10 \
  "http://localhost:8080/geoserver/rest/settings.json" 2>/dev/null \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print('  charset =', d['global']['settings'].get('charset','NOT SET'))"

echo "[+] WFS 2.0.0..."
CODE=$(docker exec geoserver-raster curl -sS -o /dev/null -w "%{http_code}" --max-time 10 \
  "http://localhost:8080/geoserver/ows?service=wfs&version=2.0.0&request=GetCapabilities")
echo "  HTTP ${CODE}"

echo "[+] WCS 2.0.1..."
CODE=$(docker exec geoserver-raster curl -sS -o /dev/null -w "%{http_code}" --max-time 10 \
  "http://localhost:8080/geoserver/ows?SERVICE=WCS&version=2.0.1&request=GetCapabilities")
echo "  HTTP ${CODE}"
REMOTE
