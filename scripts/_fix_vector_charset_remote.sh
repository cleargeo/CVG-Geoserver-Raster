#!/usr/bin/env bash
# Runs ON VM455 (ubuntu@10.10.10.204) — fix charset for geoserver-vector
set -euo pipefail

CONTAINER="geoserver-vector"
GS_URL="http://localhost:8080/geoserver/rest"
CREDS="admin:geoserver"

echo "[1/4] GET current global settings..."
docker exec "${CONTAINER}" curl -sS -u "${CREDS}" --max-time 15 \
  "${GS_URL}/settings.json" > /tmp/gs_vec_orig.json
echo "  Saved $(wc -c < /tmp/gs_vec_orig.json) bytes"

echo "[2/4] Patch charset=UTF-8 on host with python3..."
python3 << 'PYEOF'
import json
with open("/tmp/gs_vec_orig.json") as f:
    d = json.load(f)
settings = d["global"]["settings"]
settings["charset"] = "UTF-8"
# Ensure contact is not null (can cause 400)
if settings.get("contact") is None:
    settings["contact"] = {}
with open("/tmp/gs_vec_fixed.json", "w") as f:
    json.dump(d, f)
print("  charset set to:", settings["charset"])
PYEOF

echo "[3/4] Copy patched file into container..."
docker cp /tmp/gs_vec_fixed.json "${CONTAINER}":/tmp/gs_vec_fixed.json

echo "[4/4] PUT patched settings back..."
HTTP_CODE=$(docker exec "${CONTAINER}" curl -sS -o /tmp/gs_put_response.txt \
  -w "%{http_code}" -u "${CREDS}" --max-time 15 \
  -X PUT -H "Content-Type: application/json" \
  -d @/tmp/gs_vec_fixed.json \
  "${GS_URL}/settings")
echo "  PUT HTTP ${HTTP_CODE}"
if [ "${HTTP_CODE}" != "200" ]; then
  echo "  ERROR response:"
  docker exec "${CONTAINER}" cat /tmp/gs_put_response.txt
  exit 1
fi

echo ""
echo "Waiting 5s for GeoServer to reload settings..."
sleep 5

echo "[5/4] Verify charset in live settings..."
CHARSET=$(docker exec "${CONTAINER}" curl -sS -u "${CREDS}" --max-time 10 \
  "${GS_URL}/settings.json" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['global']['settings'].get('charset','NOT SET'))")
echo "  charset = ${CHARSET}"

echo "[6/4] WFS 2.0.0 GetCapabilities..."
CODE=$(docker exec "${CONTAINER}" curl -sS -o /dev/null -w "%{http_code}" --max-time 15 \
  "http://localhost:8080/geoserver/ows?service=wfs&version=2.0.0&request=GetCapabilities")
echo "  HTTP ${CODE}"

echo "[7/4] WMS 1.3.0 GetCapabilities..."
CODE=$(docker exec "${CONTAINER}" curl -sS -o /dev/null -w "%{http_code}" --max-time 15 \
  "http://localhost:8080/geoserver/ows?service=wms&version=1.3.0&request=GetCapabilities")
echo "  HTTP ${CODE}"

echo ""
echo "Done."
