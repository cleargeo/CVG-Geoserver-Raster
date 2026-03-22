#!/usr/bin/env bash
# =============================================================================
# Fix: Append localhost { tls internal } health block to Caddyfiles on both VMs
#
# Root cause of previous failure:
#   Passing multiline $LOCALHOST_BLOCK as an SSH positional argument caused
#   newlines to be interpreted as command separators on the remote shell.
#   Only blank/comment lines before "localhost {" were appended.
#
# Fix: Pipe a self-contained Python3 script directly via SSH stdin.
#   No argument splitting issues — Python receives the full Caddyfile path
#   as sys.argv[1] and the block content is embedded in the Python source.
# =============================================================================
SSH_KEY="${HOME}/.ssh/cvg_neuron_proxmox"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=no -o ConnectTimeout=10 -o LogLevel=ERROR)

fix_vm() {
  local label="$1" ip="$2" caddyfile="$3" caddy_ctr="$4"
  echo ""
  echo "=== ${label} (${ip}) ==="

  # ─── Step 1: Append localhost block via inline Python (no multiline args) ───
  echo "[1] Appending localhost health block via Python stdin pipe..."
  ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" "ubuntu@${ip}" \
    "python3 - '${caddyfile}'" << 'PYEOF'
import sys, os

CADDYFILE = sys.argv[1]

LOCALHOST_BLOCK = """

# =============================================================================
# Internal health probe block — serves /status via localhost with self-signed
# cert (tls internal). Allows:  curl -sk https://localhost/status  -> HTTP 200
# Works even before ACME certificate provisioned for the public hostname.
# =============================================================================
localhost {
    tls internal

    handle /status {
        respond "OK" 200
    }

    # Reject all other localhost paths (not a public endpoint)
    respond 404
}
"""

with open(CADDYFILE, "r") as f:
    content = f.read()

if "localhost {" in content:
    print("  localhost block already present — skipping")
else:
    with open(CADDYFILE, "a") as f:
        f.write(LOCALHOST_BLOCK)
    print("  localhost block appended successfully")

# Verify
with open(CADDYFILE, "r") as f:
    verify = f.read()
if "localhost {" in verify:
    print("  Verified: 'localhost {' found in Caddyfile")
else:
    print("  ERROR: 'localhost {' still not found after write!")
    sys.exit(1)
PYEOF

  local rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "  ERROR: Python patch step failed (exit $rc)"
    return 1
  fi

  # ─── Step 2: Validate Caddyfile syntax ───────────────────────────────────
  echo "[2] Validating Caddyfile syntax..."
  ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" "ubuntu@${ip}" \
    "docker exec '${caddy_ctr}' caddy validate --config /etc/caddy/Caddyfile 2>&1 | grep -E '(Valid|ERROR|error)'"

  # ─── Step 3: Reload Caddy ────────────────────────────────────────────────
  echo "[3] Reloading Caddy..."
  ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" "ubuntu@${ip}" \
    "docker exec '${caddy_ctr}' caddy reload --config /etc/caddy/Caddyfile 2>&1 | grep -E '(reload|error|ERROR)' | head -5"
  echo "  Reload command sent — waiting 3s..."
  sleep 3

  # ─── Step 4: Test HTTPS from inside container ─────────────────────────────
  echo "[4] Testing HTTPS localhost /status from inside container (tls internal)..."
  ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" "ubuntu@${ip}" \
    "CODE=\$(docker exec '${caddy_ctr}' curl -sk --connect-timeout 8 -o /dev/null -w '%{http_code}' https://localhost/status 2>/dev/null); echo \"  HTTPS /status (inside ctr): HTTP \${CODE}\""

  # ─── Step 5: Test admin API from inside container ─────────────────────────
  echo "[5] Testing Caddy admin API (port 2019) from inside container..."
  ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" "ubuntu@${ip}" \
    "CODE=\$(docker exec '${caddy_ctr}' curl -sf --connect-timeout 5 -o /dev/null -w '%{http_code}' http://localhost:2019/ 2>/dev/null); echo \"  Admin API /: HTTP \${CODE}\""

  # ─── Step 6: Show tail of Caddyfile to confirm block ─────────────────────
  echo "[6] Tail of Caddyfile (confirming localhost block)..."
  ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" "ubuntu@${ip}" \
    "tail -20 '${caddyfile}'"
}

fix_vm "VM454 Raster" "10.10.10.203" \
       "/opt/cvg/CVG_Geoserver_Raster/caddy/Caddyfile" \
       "caddy-gsr"

fix_vm "VM455 Vector" "10.10.10.204" \
       "/opt/cvg/CVG_Geoserver_Vector/caddy/Caddyfile" \
       "caddy-gsv"

echo ""
echo "All done. Run _check_status.sh to verify full stack state."
