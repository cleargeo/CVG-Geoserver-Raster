#!/bin/sh
# CVG GeoServer First-Run Init Script (geoserver-raster)
# Sets admin password and proxy URL via REST API. Runs once per data_dir.
set -e
GS_URL=${GEOSERVER_URL:-http://geoserver-raster:8080/geoserver}
ADMIN_USER=${GEOSERVER_ADMIN_USER:-admin}
ADMIN_PASS=${GEOSERVER_ADMIN_PASSWORD}
PROXY_URL=${PROXY_BASE_URL:-https://raster.cleargeo.tech/geoserver}
SENTINEL=/opt/geoserver/data_dir/.cvg_init_done

[ "${SKIP_IF_DONE:-true}" = "true" ] && [ -f "$SENTINEL" ] && echo "[init] Already done." && exit 0
[ -z "$ADMIN_PASS" ] && echo "[init] ERROR: GEOSERVER_ADMIN_PASSWORD not set." && exit 1

echo "[init] Waiting for GeoServer..."
for i in $(seq 1 40); do
  curl -fsS -o /dev/null "${GS_URL}/ows" && break
  echo "[init] attempt $i/40 -- sleeping 5s"; sleep 5
done

echo "[init] Setting admin password..."
curl -fsS -u admin:geoserver -X PUT -H "Content-Type: application/xml" \
  -d "<user><password>${ADMIN_PASS}</password><enabled>true</enabled></user>" \
  "${GS_URL}/rest/security/self/password"

echo "[init] Setting proxy base URL: $PROXY_URL"
curl -fsS -u "${ADMIN_USER}:${ADMIN_PASS}" -X PUT -H "Content-Type: application/json" \
  -d '{"global":{"settings":{"proxyBaseUrl":"'"$PROXY_URL"'"}}}' \
  "${GS_URL}/rest/settings"

echo "[init] Removing demo workspaces..."
for ws in sf topp cite tiger nurc; do
  curl -fsS -u "${ADMIN_USER}:${ADMIN_PASS}" -X DELETE "${GS_URL}/rest/workspaces/$ws?recurse=true" 2>/dev/null || true
done

echo "[init] Creating CVG workspace..."
curl -fsS -u "${ADMIN_USER}:${ADMIN_PASS}" -X POST -H "Content-Type: application/json" \
  -d '{"workspace":{"name":"cvg"}}' "${GS_URL}/rest/workspaces" 2>/dev/null || true

touch "$SENTINEL"
echo "[init] Done."
