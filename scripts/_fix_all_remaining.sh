#!/usr/bin/env bash
# =============================================================================
# Fix all remaining errors:
#  1. Patch Caddyfiles: LE-only + localhost health block
#  2. Reload Caddy on both VMs
#  3. Restart init containers → exit 0 (sentinel check)
# =============================================================================
SSH_KEY="${HOME}/.ssh/cvg_neuron_proxmox"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR)

LOCALHOST_BLOCK='

# =============================================================================
# Internal health probe block — serves /status via localhost with self-signed
# cert (tls internal). Allows:  curl -sk https://localhost/status  -> HTTP 200
# Works even before ACME certificate is provisioned for the public hostname.
# =============================================================================
localhost {
    tls internal

    handle /status {
        respond "OK" 200
    }

    # Reject all other localhost paths (not a public endpoint)
    respond 404
}'

patch_vm() {
  local label="$1" ip="$2" caddyfile="$3" caddy_ctr="$4"
  echo ""
  echo "=== ${label} (${ip}) ==="

  ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" "ubuntu@${ip}" bash -s -- "${caddyfile}" "${caddy_ctr}" "${LOCALHOST_BLOCK}" << 'REMOTE'
CADDYFILE="$1"
CTR="$2"
LBLOCK="$3"

echo "[1] Patching global block: Add acme_ca for LE-only (no ZeroSSL fallback)..."
python3 << PYEOF
import re

with open("${CADDYFILE}") as f:
    content = f.read()

# Replace the global options block to add acme_ca for LE only
# Pattern: the { email ... } block at the top
old_global = """{
    email azelenski@clearviewgeographic.com

    # Uncomment to use staging CA while testing (avoids LE rate limits):
    # acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
}"""
new_global = """{
    email azelenski@clearviewgeographic.com

    # Use Let's Encrypt only — disables ZeroSSL fallback (ZeroSSL EAB not configured,
    # causing "response Content-Type is text/html" errors in Caddy logs)
    # Switch to staging URL to test without LE rate limits:
    # acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
    acme_ca https://acme-v02.api.letsencrypt.org/directory
}"""

if old_global in content:
    content = content.replace(old_global, new_global)
    print("  Global block patched (acme_ca added)")
elif "acme_ca https://acme-v02.api.letsencrypt.org/directory" in content:
    print("  Global block already patched — skipping")
else:
    print("  WARN: Global block pattern not found — check manually")

with open("${CADDYFILE}", "w") as f:
    f.write(content)
PYEOF

echo "[2] Checking/adding localhost health block..."
if grep -q "localhost {" "${CADDYFILE}"; then
  echo "  localhost block already present — skipping"
else
  printf '%s\n' "${LBLOCK}" >> "${CADDYFILE}"
  echo "  localhost block appended"
fi

echo "[3] Validating Caddyfile syntax..."
docker exec "${CTR}" caddy validate --config /etc/caddy/Caddyfile 2>&1 \
  && echo "  Syntax OK" \
  || { echo "  ERROR: Caddyfile syntax invalid!"; exit 1; }

echo "[4] Reloading Caddy (hot-reload, zero-downtime)..."
docker exec "${CTR}" caddy reload --config /etc/caddy/Caddyfile 2>&1 \
  && echo "  Caddy reloaded successfully" \
  || { echo "  ERROR: Caddy reload failed!"; exit 1; }

sleep 2

echo "[5] Testing HTTPS localhost /status after reload..."
CODE=$(curl -sk --connect-timeout 8 -o /dev/null -w "%{http_code}" \
  "https://localhost/status" 2>/dev/null || echo "ERR")
echo "  HTTPS /status: HTTP ${CODE}"

echo "[6] Restarting init container to get clean exit(0)..."
INIT_CTR="${CTR%-*}-init"
if ! echo "${CTR}" | grep -q "raster\|vector"; then
  INIT_CTR="geoserver-init"
fi
# Derive init container name from main container name
if [[ "${CTR}" == "caddy-gsr" ]]; then
  INIT_CTR="geoserver-raster-init"
elif [[ "${CTR}" == "caddy-gsv" ]]; then
  INIT_CTR="geoserver-vector-init"
fi

INIT_STATUS=$(docker inspect --format '{{.State.Status}}' "${INIT_CTR}" 2>/dev/null || echo "not_found")
echo "  Init container '${INIT_CTR}' current state: ${INIT_STATUS}"

if [[ "${INIT_STATUS}" == "exited" ]]; then
  docker start "${INIT_CTR}" 2>/dev/null
  echo "  Started ${INIT_CTR} — waiting 5s for sentinel check..."
  sleep 5
  NEW_STATUS=$(docker inspect --format '{{.State.Status}} (exit {{.State.ExitCode}})' "${INIT_CTR}" 2>/dev/null)
  echo "  New status: ${NEW_STATUS}"
else
  echo "  Init container not in exited state — skipping"
fi
REMOTE
}

patch_vm "VM454 Raster" "10.10.10.203" "/opt/cvg/CVG_Geoserver_Raster/caddy/Caddyfile" "caddy-gsr"
patch_vm "VM455 Vector" "10.10.10.204" "/opt/cvg/CVG_Geoserver_Vector/caddy/Caddyfile" "caddy-gsv"

echo ""
echo "All done. Run _check_status.sh to verify clean state."
