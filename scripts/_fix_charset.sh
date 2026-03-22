#!/usr/bin/env bash
# Fix GeoServer WFS 2.0.0 "Null charset name" by re-patching global settings
# with charset=UTF-8 on both VMs.
SSH_KEY="${HOME}/.ssh/cvg_neuron_proxmox"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR)

patch_charset() {
  local label="$1" ip="$2" proxy_url="$3"
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  Patching charset on ${label} (${ip})"
  echo "═══════════════════════════════════════════════════════"
  ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" "ubuntu@${ip}" bash << REMOTE
set -euo pipefail

echo "[+] PATCHing global settings with charset=UTF-8..."
HTTP_CODE=\$(docker exec geoserver-raster curl -sS -o /tmp/gs_settings.json \
  -u admin:geoserver --max-time 10 \
  "http://localhost:8080/geoserver/rest/settings.json" -w "%{http_code}")
echo "  GET settings: HTTP \${HTTP_CODE}"

# Patch charset into the response and PUT it back
docker exec geoserver-raster sh -c '
  python3 -c "
import json, sys
with open(\"/tmp/gs_settings.json\") as f:
    d = json.load(f)
settings = d[\"global\"][\"settings\"]
settings[\"charset\"] = \"UTF-8\"
if \"contact\" in settings and settings[\"contact\"] is None:
    settings[\"contact\"] = {}
print(json.dumps(d))
" > /tmp/gs_settings_fixed.json
'

HTTP_CODE=\$(docker exec geoserver-raster curl -sS -o /dev/null -w "%{http_code}" \
  -u admin:geoserver --max-time 10 \
  -X PUT -H "Content-Type: application/json" \
  -d @/tmp/gs_settings_fixed.json \
  "http://localhost:8080/geoserver/rest/settings")
echo "  PUT fixed settings: HTTP \${HTTP_CODE}"

echo "[+] Verifying WFS 2.0.0 now works..."
sleep 3
HTTP_CODE=\$(docker exec geoserver-raster curl -sS -o /dev/null -w "%{http_code}" \
  --max-time 10 \
  "http://localhost:8080/geoserver/ows?service=wfs&version=2.0.0&request=GetCapabilities")
echo "  WFS 2.0.0 GetCapabilities: HTTP \${HTTP_CODE}"

echo "[+] Verifying WCS 2.0.1 with uppercase SERVICE..."
HTTP_CODE=\$(docker exec geoserver-raster curl -sS -o /dev/null -w "%{http_code}" \
  --max-time 10 \
  "http://localhost:8080/geoserver/ows?SERVICE=WCS&version=2.0.1&request=GetCapabilities")
echo "  WCS 2.0.1 GetCapabilities: HTTP \${HTTP_CODE}"

REMOTE
}

# ── Patch both VMs ────────────────────────────────────────────────────────────
ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" ubuntu@10.10.10.203 bash << 'REMOTE'
echo "[+] PATCHing global settings with charset=UTF-8 on Raster..."
HTTP_CODE=$(docker exec geoserver-raster curl -sS -o /tmp/gs_settings.json \
  -u admin:geoserver --max-time 10 \
  "http://localhost:8080/geoserver/rest/settings.json" -w "%{http_code}")
echo "  GET settings: HTTP ${HTTP_CODE}"
docker exec geoserver-raster sh -c '
  python3 -c "
import json
with open(\"/tmp/gs_settings.json\") as f: d=json.load(f)
d[\"global\"][\"settings\"][\"charset\"]=\"UTF-8\"
print(json.dumps(d))
" > /tmp/gs_fixed.json'
HTTP_CODE=$(docker exec geoserver-raster curl -sS -o /dev/null -w "%{http_code}" \
  -u admin:geoserver --max-time 10 -X PUT -H "Content-Type: application/json" \
  -d @/tmp/gs_fixed.json "http://localhost:8080/geoserver/rest/settings")
echo "  PUT fixed: HTTP ${HTTP_CODE}"
sleep 3
echo "  WFS 2.0.0: $(docker exec geoserver-raster curl -sS -o /dev/null -w "%{http_code}" \
  --max-time 10 "http://localhost:8080/geoserver/ows?service=wfs&version=2.0.0&request=GetCapabilities")"
echo "  WCS 2.0.1: $(docker exec geoserver-raster curl -sS -o /dev/null -w "%{http_code}" \
  --max-time 10 "http://localhost:8080/geoserver/ows?SERVICE=WCS&version=2.0.1&request=GetCapabilities")"
REMOTE

echo ""
ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" ubuntu@10.10.10.204 bash << 'REMOTE'
echo "[+] PATCHing global settings with charset=UTF-8 on Vector..."
HTTP_CODE=$(docker exec geoserver-vector curl -sS -o /tmp/gs_settings.json \
  -u admin:geoserver --max-time 10 \
  "http://localhost:8080/geoserver/rest/settings.json" -w "%{http_code}")
echo "  GET settings: HTTP ${HTTP_CODE}"
docker exec geoserver-vector sh -c '
  python3 -c "
import json
with open(\"/tmp/gs_settings.json\") as f: d=json.load(f)
d[\"global\"][\"settings\"][\"charset\"]=\"UTF-8\"
print(json.dumps(d))
" > /tmp/gs_fixed.json'
HTTP_CODE=$(docker exec geoserver-vector curl -sS -o /dev/null -w "%{http_code}" \
  -u admin:geoserver --max-time 10 -X PUT -H "Content-Type: application/json" \
  -d @/tmp/gs_fixed.json "http://localhost:8080/geoserver/rest/settings")
echo "  PUT fixed: HTTP ${HTTP_CODE}"
sleep 3
echo "  WFS 2.0.0: $(docker exec geoserver-vector curl -sS -o /dev/null -w "%{http_code}" \
  --max-time 10 "http://localhost:8080/geoserver/ows?service=wfs&version=2.0.0&request=GetCapabilities")"
echo "  WMS 1.3.0: $(docker exec geoserver-vector curl -sS -o /dev/null -w "%{http_code}" \
  --max-time 10 "http://localhost:8080/geoserver/ows?service=wms&version=1.3.0&request=GetCapabilities")"
REMOTE

echo ""
echo "Done."
