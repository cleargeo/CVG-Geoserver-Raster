#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  _check_status.sh — GeoServer Raster + Vector health check
#  Resilient: guards every docker exec with an inspect state check so the
#  script never crashes with "OCI exec in stopped container" during restarts.
# ══════════════════════════════════════════════════════════════════════════════

SSH_KEY="${HOME}/.ssh/cvg_neuron_proxmox"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
          -o ConnectTimeout=10 -o LogLevel=ERROR)

RASTER_IP="10.10.10.203"
VECTOR_IP="10.10.10.204"

# -- helper: run a remote block and label the VM ------------------------------
check_vm() {
  local label="$1" ip="$2"
  shift 2
  echo ""
  echo "=================================================="
  printf "  %s  (%s)\n" "$label" "$ip"
  echo "=================================================="
  ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" "ubuntu@${ip}" bash -s -- "$@"
}

# ==============================================================================
#  RASTER -- VM454 @ 10.10.10.203
# ==============================================================================
check_vm "VM454 — GeoServer RASTER" "$RASTER_IP" << 'REMOTE'

GS_CTR="geoserver-raster"

# -- helper: returns 0 only if container exists AND is running ----------------
ctr_running() {
  local name="$1"
  local state
  state=$(docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null)
  [[ "$state" == "running" ]]
}

# -- helper: exec curl inside container, falls back gracefully ----------------
exec_curl() {
  local ctr="$1"; shift
  if ctr_running "$ctr"; then
    docker exec "$ctr" curl -sf --connect-timeout 8 -o /dev/null -w "HTTP %{http_code}" \
      "$@" 2>/dev/null || echo -n "FAILED"
  else
    local state
    state=$(docker inspect --format '{{.State.Status}}' "$ctr" 2>/dev/null || echo "absent")
    echo -n "SKIP (container $state)"
  fi
}

# --- 1. Container table -------------------------------------------------------
echo "--- Docker containers ---"
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" \
  --filter "name=geoserver-raster" \
  --filter "name=caddy-gsr" \
  --filter "name=watchtower-gsr"

# Note init container separately (one-shot, may be Exited)
INIT_STATUS=$(docker inspect --format '{{.State.Status}} (exit {{.State.ExitCode}})' \
  geoserver-raster-init 2>/dev/null || echo "not found")
echo "  [init]  geoserver-raster-init: ${INIT_STATUS}"

# --- 2. GeoServer health checks (via docker exec) ----------------------------
echo ""
echo "--- Internal GeoServer health (via docker exec) ---"

printf "  %-28s " "Web UI:"
exec_curl "$GS_CTR" "http://localhost:8080/geoserver/web/"
echo ""

printf "  %-28s " "WMS GetCapabilities:"
exec_curl "$GS_CTR" \
  "http://localhost:8080/geoserver/ows?service=wms&version=1.3.0&request=GetCapabilities"
echo ""

printf "  %-28s " "WFS GetCapabilities:"
exec_curl "$GS_CTR" \
  "http://localhost:8080/geoserver/ows?service=wfs&version=2.0.0&request=GetCapabilities"
echo ""

printf "  %-28s " "WCS GetCapabilities:"
exec_curl "$GS_CTR" \
  "http://localhost:8080/geoserver/ows?SERVICE=WCS&version=2.0.1&request=GetCapabilities"
echo ""

# charset sanity check
printf "  %-28s " "charset (REST API):"
docker exec "$GS_CTR" curl -sS -u admin:geoserver --max-time 8 \
  "http://localhost:8080/geoserver/rest/settings.json" 2>/dev/null \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['global']['settings'].get('charset','NOT SET'))" \
  2>/dev/null || echo -n "SKIP"
echo ""

# --- 3. Caddy public entry point ---------------------------------------------
echo ""
echo "--- Caddy (public entry point, :80 + :443) ---"
printf "  %-28s " "HTTP->HTTPS redirect:"
CODE=$(curl -sf --connect-timeout 8 -o /dev/null -w "%{http_code}" \
  "http://localhost:80/" 2>/dev/null || echo "ERR")
echo "HTTP ${CODE}"

# HTTPS health probe via docker exec (inside container) — avoids DNS/cert
# dependency; uses tls internal self-signed cert on the localhost site block
printf "  %-28s " "HTTPS /status (docker exec):"
CODE=$(docker exec caddy-gsr curl -sk --connect-timeout 8 \
  -o /dev/null -w "%{http_code}" \
  "https://localhost/status" 2>/dev/null || echo "ERR")
echo "HTTP ${CODE}"

# Caddy admin API — verifies Caddy's config endpoint is live (plain HTTP,
# bound to 127.0.0.1:2019 inside the container; use docker exec)
printf "  %-28s " "Caddy admin API (/config/):"
CODE=$(docker exec caddy-gsr curl -sf --connect-timeout 5 \
  -o /dev/null -w "%{http_code}" \
  "http://localhost:2019/config/" 2>/dev/null || echo "ERR")
echo "HTTP ${CODE}"

# --- 4. TLS certificate status -----------------------------------------------
echo ""
echo "--- TLS / ACME cert status (raster.cleargeo.tech) ---"
ACME_DIR="/data/caddy/certificates"
if docker exec caddy-gsr test -d "$ACME_DIR" 2>/dev/null; then
  CERTS=$(docker exec caddy-gsr find "$ACME_DIR" -name "*.crt" 2>/dev/null)
  if [[ -n "$CERTS" ]]; then
    echo "  Stored certs:"
    echo "$CERTS" | sed 's|^|    |'
  else
    echo "  Cert dir exists but no .crt files yet (ACME still provisioning)"
  fi
else
  echo "  No cert directory found yet (Caddy may still be provisioning)"
  echo "  Check: docker exec caddy-gsr ls /data/caddy/"
fi

REMOTE

# ==============================================================================
#  VECTOR -- VM455 @ 10.10.10.204
# ==============================================================================
check_vm "VM455 — GeoServer VECTOR" "$VECTOR_IP" << 'REMOTE'

GS_CTR="geoserver-vector"

ctr_running() {
  local name="$1"
  local state
  state=$(docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null)
  [[ "$state" == "running" ]]
}

exec_curl() {
  local ctr="$1"; shift
  if ctr_running "$ctr"; then
    docker exec "$ctr" curl -sf --connect-timeout 8 -o /dev/null -w "HTTP %{http_code}" \
      "$@" 2>/dev/null || echo -n "FAILED"
  else
    local state
    state=$(docker inspect --format '{{.State.Status}}' "$ctr" 2>/dev/null || echo "absent")
    echo -n "SKIP (container $state)"
  fi
}

# --- 1. Container table -------------------------------------------------------
echo "--- Docker containers ---"
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" \
  --filter "name=geoserver-vector" \
  --filter "name=caddy-gsv" \
  --filter "name=watchtower-gsv"

INIT_STATUS=$(docker inspect --format '{{.State.Status}} (exit {{.State.ExitCode}})' \
  geoserver-vector-init 2>/dev/null || echo "not found")
echo "  [init]  geoserver-vector-init: ${INIT_STATUS}"

# --- 2. GeoServer health checks ----------------------------------------------
echo ""
echo "--- Internal GeoServer health (via docker exec) ---"

printf "  %-28s " "Web UI:"
exec_curl "$GS_CTR" "http://localhost:8080/geoserver/web/"
echo ""

printf "  %-28s " "WFS GetCapabilities:"
exec_curl "$GS_CTR" \
  "http://localhost:8080/geoserver/ows?service=wfs&version=2.0.0&request=GetCapabilities"
echo ""

printf "  %-28s " "WMS GetCapabilities:"
exec_curl "$GS_CTR" \
  "http://localhost:8080/geoserver/ows?service=wms&version=1.3.0&request=GetCapabilities"
echo ""

# charset sanity check
printf "  %-28s " "charset (REST API):"
docker exec "$GS_CTR" curl -sS -u admin:geoserver --max-time 8 \
  "http://localhost:8080/geoserver/rest/settings.json" 2>/dev/null \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['global']['settings'].get('charset','NOT SET'))" \
  2>/dev/null || echo -n "SKIP"
echo ""

# --- 3. Caddy public entry point ---------------------------------------------
echo ""
echo "--- Caddy (public entry point, :80 + :443) ---"
printf "  %-28s " "HTTP->HTTPS redirect:"
CODE=$(curl -sf --connect-timeout 8 -o /dev/null -w "%{http_code}" \
  "http://localhost:80/" 2>/dev/null || echo "ERR")
echo "HTTP ${CODE}"

# HTTPS health probe via docker exec (inside container) — avoids DNS/cert
# dependency; uses tls internal self-signed cert on the localhost site block
printf "  %-28s " "HTTPS /status (docker exec):"
CODE=$(docker exec caddy-gsv curl -sk --connect-timeout 8 \
  -o /dev/null -w "%{http_code}" \
  "https://localhost/status" 2>/dev/null || echo "ERR")
echo "HTTP ${CODE}"

# Caddy admin API — verifies Caddy's config endpoint is live (plain HTTP,
# bound to 127.0.0.1:2019 inside the container; use docker exec)
printf "  %-28s " "Caddy admin API (/config/):"
CODE=$(docker exec caddy-gsv curl -sf --connect-timeout 5 \
  -o /dev/null -w "%{http_code}" \
  "http://localhost:2019/config/" 2>/dev/null || echo "ERR")
echo "HTTP ${CODE}"

# --- 4. TLS certificate status -----------------------------------------------
echo ""
echo "--- TLS / ACME cert status (vector.cleargeo.tech) ---"
ACME_DIR="/data/caddy/certificates"
if docker exec caddy-gsv test -d "$ACME_DIR" 2>/dev/null; then
  CERTS=$(docker exec caddy-gsv find "$ACME_DIR" -name "*.crt" 2>/dev/null)
  if [[ -n "$CERTS" ]]; then
    echo "  Stored certs:"
    echo "$CERTS" | sed 's|^|    |'
  else
    echo "  Cert dir exists but no .crt files yet (ACME still provisioning)"
  fi
else
  echo "  No cert directory found yet"
fi

# --- 5. DNS resolution -------------------------------------------------------
echo ""
echo "--- DNS resolution ---"
printf "  %-28s " "vector.cleargeo.tech->:"
dig +short vector.cleargeo.tech A 2>/dev/null | head -1 || echo "dig not available"
echo "  (must point to VM455 public IP — currently old platform IP if 131.148.52.231)"

printf "  %-28s " "raster.cleargeo.tech->:"
dig +short raster.cleargeo.tech A 2>/dev/null | head -1 || echo "dig not available"
echo ""

REMOTE

echo ""
echo "Done."
