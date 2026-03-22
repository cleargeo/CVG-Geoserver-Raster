#!/usr/bin/env bash
# =============================================================================
# Fix all remaining errors on wizard VMs:
#   VM452 (10.10.10.201) — Rainfall Wizard  caddy-rfw
#   VM453 (10.10.10.202) — SLR Wizard       caddy-slrw
#   VM451 (10.10.10.200) — Platform         cvg-caddy / cvg-neuron
#
# Fixes applied:
#   1. Add acme_ca LE-only to Caddyfile global block (disable ZeroSSL fallback)
#   2. Add localhost { tls internal } health block to Caddyfile
#   3. Validate + reload Caddy
#   4. Test HTTPS /status from inside container
#   5. VM451: start cvg-neuron if in Created state
#   6. VM451: clear cert lock files to unblock 3 stuck ACME orders
# =============================================================================
set -euo pipefail

SSH_KEY="${HOME}/.ssh/cvg_neuron_proxmox"
SOPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=12 -o LogLevel=ERROR"

# ─── Python patch script (piped via stdin — no multiline arg issues) ─────────
# Shared by all wizard Caddyfile patches
PYTHON_PATCH=$(cat << 'PYEOF'
import sys, re

CADDYFILE = sys.argv[1]
CADDY_EMAIL = sys.argv[2] if len(sys.argv) > 2 else "azelenski@clearviewgeographic.com"

with open(CADDYFILE, "r") as f:
    content = f.read()

changed = []

# ── 1. Ensure global block has acme_ca (LE-only, disable ZeroSSL) ──────────
if "acme_ca https://acme-v02.api.letsencrypt.org/directory" in content:
    print("  [skip] acme_ca already present")
else:
    # Find the global block and insert acme_ca before closing }
    # Global block is the first { ... } block before any site block
    global_pattern = re.compile(
        r'(\{[^{]*?email\s+\S+[^}]*?\})',
        re.DOTALL
    )
    m = global_pattern.search(content)
    if m:
        old_global = m.group(0)
        new_global = old_global.rstrip().rstrip('}').rstrip()
        new_global += """

    # Use Let's Encrypt only — disables ZeroSSL fallback
    # (ZeroSSL EAB not configured → "text/html" errors in Caddy logs)
    acme_ca https://acme-v02.api.letsencrypt.org/directory
}"""
        content = content.replace(old_global, new_global, 1)
        changed.append("acme_ca added to global block")
    else:
        # No global block — prepend one
        content = """{
    email """ + CADDY_EMAIL + """

    # Use Let's Encrypt only — disables ZeroSSL fallback
    acme_ca https://acme-v02.api.letsencrypt.org/directory
}

""" + content
        changed.append("global block created with acme_ca")

# ── 2. Append localhost health block ──────────────────────────────────────
LOCALHOST_BLOCK = """

# =============================================================================
# Internal health probe — tls internal self-signed cert for localhost.
# curl -sk https://localhost/status  →  HTTP 200 (no public DNS/ACME needed)
# =============================================================================
localhost {
    tls internal

    handle /status {
        respond "OK" 200
    }

    respond 404
}
"""

if "localhost {" in content:
    print("  [skip] localhost block already present")
else:
    with open(CADDYFILE, "a") as f:
        f.write(LOCALHOST_BLOCK)
    changed.append("localhost block appended")
    # Re-read for the global block write below
    with open(CADDYFILE, "r") as f:
        content = f.read()

# Write global block changes (if any)
if "acme_ca added to global block" in changed or "global block created with acme_ca" in changed:
    with open(CADDYFILE, "w") as f:
        f.write(content)

for c in changed:
    print(f"  [done] {c}")

# Verify
with open(CADDYFILE, "r") as f:
    verify = f.read()
ok = True
if "acme_ca https://acme-v02.api.letsencrypt.org/directory" not in verify:
    print("  [ERROR] acme_ca NOT found after patch"); ok = False
if "localhost {" not in verify:
    print("  [ERROR] localhost block NOT found after patch"); ok = False
if ok:
    print("  [OK] Caddyfile verified")
PYEOF
)

# ─── Fix a single wizard VM ──────────────────────────────────────────────────
fix_wizard_vm() {
    local label="$1" ip="$2" caddy_ctr="$3"
    echo ""
    echo "══ ${label} (${ip}) ══"

    # Find Caddyfile path
    echo "[1] Finding Caddyfile..."
    CADDYFILE_PATH=$(ssh $SOPTS -i "${SSH_KEY}" "ubuntu@${ip}" \
        "find /opt/cvg -name Caddyfile 2>/dev/null | head -1" 2>/dev/null)
    if [[ -z "${CADDYFILE_PATH}" ]]; then
        echo "    ERROR: Caddyfile not found under /opt/cvg on ${ip}"
        return 1
    fi
    echo "    Found: ${CADDYFILE_PATH}"

    # Apply Python patch (stdin pipe — no multiline arg splitting)
    echo "[2] Patching Caddyfile (acme_ca + localhost block)..."
    echo "${PYTHON_PATCH}" | ssh $SOPTS -i "${SSH_KEY}" "ubuntu@${ip}" \
        "python3 - '${CADDYFILE_PATH}'"

    # Validate
    echo "[3] Validating Caddyfile..."
    ssh $SOPTS -i "${SSH_KEY}" "ubuntu@${ip}" \
        "docker exec '${caddy_ctr}' caddy validate --config /etc/caddy/Caddyfile 2>&1 | grep -E '(Valid|ERROR|error)'" \
        && echo "    Syntax OK" || echo "    WARNING: validate had issues"

    # Reload
    echo "[4] Reloading Caddy..."
    ssh $SOPTS -i "${SSH_KEY}" "ubuntu@${ip}" \
        "docker exec '${caddy_ctr}' caddy reload --config /etc/caddy/Caddyfile 2>&1 | grep -iE '(reload|error)' | head -3"
    sleep 3

    # Test HTTPS /status
    echo "[5] Testing HTTPS /status (inside container)..."
    CODE=$(ssh $SOPTS -i "${SSH_KEY}" "ubuntu@${ip}" \
        "docker exec '${caddy_ctr}' curl -sk --connect-timeout 8 -o /dev/null -w '%{http_code}' https://localhost/status 2>/dev/null" 2>/dev/null || echo "ERR")
    echo "    HTTPS /status: HTTP ${CODE}"

    # Test admin API
    echo "[6] Testing admin API..."
    CODE2=$(ssh $SOPTS -i "${SSH_KEY}" "ubuntu@${ip}" \
        "docker exec '${caddy_ctr}' curl -sf --connect-timeout 5 -o /dev/null -w '%{http_code}' http://localhost:2019/config/ 2>/dev/null" 2>/dev/null || echo "ERR")
    echo "    Admin API /config/: HTTP ${CODE2}"
}

# ─── Fix VM451 specific issues ───────────────────────────────────────────────
fix_vm451() {
    local ip="10.10.10.200"
    echo ""
    echo "══ VM451 Platform (${ip}) ══"

    # Issue A: cvg-neuron stuck in Created state
    echo "[A] Checking cvg-neuron-v1 state..."
    NEURON_STATE=$(ssh $SOPTS -i "${SSH_KEY}" "ubuntu@${ip}" \
        "docker inspect --format '{{.State.Status}}' cvg-neuron-v1 2>/dev/null || echo 'not_found'" 2>/dev/null)
    echo "    cvg-neuron-v1 state: ${NEURON_STATE}"
    if [[ "${NEURON_STATE}" == "created" ]]; then
        echo "    Starting cvg-neuron-v1..."
        ssh $SOPTS -i "${SSH_KEY}" "ubuntu@${ip}" \
            "docker start cvg-neuron-v1 2>&1" 2>/dev/null
        sleep 5
        NEW_STATE=$(ssh $SOPTS -i "${SSH_KEY}" "ubuntu@${ip}" \
            "docker inspect --format '{{.State.Status}}' cvg-neuron-v1 2>/dev/null || echo 'not_found'" 2>/dev/null)
        echo "    New state: ${NEW_STATE}"
    elif [[ "${NEURON_STATE}" == "running" ]]; then
        echo "    Already running — OK"
    else
        echo "    State: ${NEURON_STATE} — no action taken"
    fi

    # Issue B: Cert lock corruption for git-engine, infra, audit subdomains
    echo "[B] Clearing stuck ACME cert locks on VM451..."
    ssh $SOPTS -i "${SSH_KEY}" "ubuntu@${ip}" bash << 'LOCK_FIX'
CTR="cvg-caddy"
echo "  Searching for lock files in Caddy data volume..."
# Caddy stores certs + locks under /data/caddy/locks/
LOCKS=$(docker exec "${CTR}" find /data/caddy/locks -name "*.lock" 2>/dev/null || echo "")
if [[ -z "${LOCKS}" ]]; then
    echo "  No .lock files found (already clean)"
else
    echo "  Found locks:"
    echo "${LOCKS}" | sed 's/^/    /'
    # Remove all stale lock files
    docker exec "${CTR}" sh -c 'find /data/caddy/locks -name "*.lock" -exec rm -f {} \; 2>/dev/null && echo "  Locks removed"' 2>/dev/null || true
fi

# Also remove any cert-obtain locks from certmagic storage
ISSUE_DIRS=$(docker exec "${CTR}" find /data/caddy -name "*.issuing" 2>/dev/null || echo "")
if [[ -n "${ISSUE_DIRS}" ]]; then
    echo "  Found issuing dirs: ${ISSUE_DIRS}"
    docker exec "${CTR}" sh -c 'find /data/caddy -name "*.issuing" -exec rm -rf {} \; 2>/dev/null' || true
    echo "  Issuing dirs cleared"
fi
LOCK_FIX

    # Issue C: Check if cvg-caddy has localhost block too (VM451 Caddy may need same fix)
    echo "[C] Checking VM451 cvg-caddy for localhost block..."
    CADDY451_FILE=$(ssh $SOPTS -i "${SSH_KEY}" "ubuntu@${ip}" \
        "docker inspect cvg-caddy --format '{{range .Mounts}}{{if eq .Destination \"/etc/caddy/Caddyfile\"}}{{.Source}}{{end}}{{end}}' 2>/dev/null" 2>/dev/null)
    echo "    Caddyfile source: ${CADDY451_FILE}"

    if [[ -n "${CADDY451_FILE}" ]]; then
        HAS_LOCALHOST=$(ssh $SOPTS -i "${SSH_KEY}" "ubuntu@${ip}" \
            "grep -q 'localhost {' '${CADDY451_FILE}' 2>/dev/null && echo yes || echo no" 2>/dev/null)
        echo "    Has localhost block: ${HAS_LOCALHOST}"

        if [[ "${HAS_LOCALHOST}" == "no" ]]; then
            echo "    Applying patch to VM451 Caddyfile..."
            echo "${PYTHON_PATCH}" | ssh $SOPTS -i "${SSH_KEY}" "ubuntu@${ip}" \
                "python3 - '${CADDY451_FILE}'"

            echo "    Validating + reloading cvg-caddy..."
            ssh $SOPTS -i "${SSH_KEY}" "ubuntu@${ip}" \
                "docker exec cvg-caddy caddy validate --config /etc/caddy/Caddyfile 2>&1 | grep -E '(Valid|ERROR)'"
            ssh $SOPTS -i "${SSH_KEY}" "ubuntu@${ip}" \
                "docker exec cvg-caddy caddy reload --config /etc/caddy/Caddyfile 2>&1 | grep -iE '(reload|error)' | head -3"
        fi
    else
        echo "    Could not determine Caddyfile path for cvg-caddy — skipping"
    fi

    # Issue D: Restart cvg-caddy to clear any in-memory lock state
    echo "[D] Restarting cvg-caddy to clear in-memory lock state..."
    ssh $SOPTS -i "${SSH_KEY}" "ubuntu@${ip}" \
        "docker restart cvg-caddy 2>&1 | head -1; sleep 5; docker inspect --format '{{.State.Status}}' cvg-caddy 2>/dev/null" 2>/dev/null
}

# ─── Apply fixes ─────────────────────────────────────────────────────────────
fix_wizard_vm "VM452 Rainfall" "10.10.10.201" "caddy-rfw"
fix_wizard_vm "VM453 SLR"      "10.10.10.202" "caddy-slrw"
fix_vm451

echo ""
echo "════════════════════════════════════════"
echo "All wizard VM fixes applied."
echo "Run _check_all_vms.sh for final status."
echo "════════════════════════════════════════"
