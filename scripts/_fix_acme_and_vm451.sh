#!/usr/bin/env bash
# Fix acme_ca on VM452/VM453 + localhost block on VM451 Caddyfile (sudo)
set -euo pipefail

SSH_KEY="${HOME}/.ssh/cvg_neuron_proxmox"
SOPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=12 -o LogLevel=ERROR"

# ─── Inline Python: patch global block with acme_ca only (localhost already there) ──
apply_acme_ca() {
    local ip="$1" cf="$2" ctr="$3" use_sudo="${4:-}"
    echo ""
    echo "── acme_ca fix: ${ip} ──"

    local py_cmd="python3"
    [[ -n "${use_sudo}" ]] && py_cmd="sudo python3"

    ssh ${SOPTS} -i "${SSH_KEY}" "ubuntu@${ip}" "${py_cmd} - '${cf}'" << 'PYEOF'
import sys, re
cf = sys.argv[1]
with open(cf) as f:
    txt = f.read()

if 'acme_ca https://acme-v02.api.letsencrypt.org/directory' in txt:
    print('  acme_ca already present — skip')
    sys.exit(0)

# Locate global block: first {...} block that contains an email directive
m = re.search(r'(\{[^{]*?email\s+\S+[^{]*?\})', txt, re.DOTALL)
if not m:
    print('  ERROR: global block with email not found')
    sys.exit(1)

old_blk = m.group(0)
# Insert acme_ca directive before the closing brace
new_blk = old_blk.rstrip()
if new_blk.endswith('}'):
    new_blk = new_blk[:-1].rstrip()
new_blk += '\n\n    # Use Let\'s Encrypt only (disable ZeroSSL fallback)\n    acme_ca https://acme-v02.api.letsencrypt.org/directory\n}'

result = txt.replace(old_blk, new_blk, 1)
with open(cf, 'w') as f:
    f.write(result)

# Verify both directives are present
with open(cf) as f:
    v = f.read()
ok_acme     = 'acme_ca https://acme-v02.api.letsencrypt.org/directory' in v
ok_lhost    = 'localhost {' in v

if ok_acme and ok_lhost:
    print('  [OK] acme_ca patched, localhost block confirmed present')
elif ok_acme:
    print('  [OK] acme_ca patched (localhost block missing — may need separate fix)')
else:
    print('  [ERROR] acme_ca NOT found after write — check manually')
    sys.exit(1)
PYEOF

    echo "  Reloading Caddy ${ctr}..."
    ssh ${SOPTS} -i "${SSH_KEY}" "ubuntu@${ip}" \
        "docker exec '${ctr}' caddy reload --config /etc/caddy/Caddyfile 2>&1 | grep -iE '(reload|error)' | head -3 || true"
    sleep 2

    echo "  Verifying acme_ca in running config..."
    LE=$(ssh ${SOPTS} -i "${SSH_KEY}" "ubuntu@${ip}" \
        "docker exec '${ctr}' curl -sf http://localhost:2019/config/ 2>/dev/null | python3 -c \"import json,sys; cfg=json.load(sys.stdin); issuers=[i.get('ca','') for a in cfg.get('apps',{}).get('tls',{}).get('automation',{}).get('policies',[]) for i in a.get('issuers',[])] + [cfg.get('apps',{}).get('tls',{}).get('automation',{}).get('on_demand',{}).get('permission',{}).get('ca','')]; print('LE-only' if any('acme-v02.api.letsencrypt.org' in c for c in issuers) else 'multiple-or-unset')\" 2>/dev/null || echo 'check-manually'" 2>/dev/null || echo "api-err")
    echo "  CA config: ${LE}"
}

# VM452 — Rainfall
apply_acme_ca "10.10.10.201" \
    "/opt/cvg/CVG_Rainfall_Wizard/caddy/Caddyfile" \
    "caddy-rfw"

# VM453 — SLR
apply_acme_ca "10.10.10.202" \
    "/opt/cvg/CVG_SLR_Wizard/caddy/Caddyfile" \
    "caddy-slrw"

# ─── VM451: patch /opt/cvg-platform/Caddyfile with sudo ─────────────────────
echo ""
echo "── VM451 Caddyfile (sudo) ──"

ssh ${SOPTS} -i "${SSH_KEY}" "ubuntu@10.10.10.200" "sudo python3 - '/opt/cvg-platform/Caddyfile'" << 'PYEOF'
import sys, re
cf = sys.argv[1]
with open(cf) as f:
    txt = f.read()

changed = False

# 1. acme_ca
if 'acme_ca https://acme-v02.api.letsencrypt.org/directory' not in txt:
    m = re.search(r'(\{[^{]*?email\s+\S+[^{]*?\})', txt, re.DOTALL)
    if m:
        old_blk = m.group(0)
        new_blk = old_blk.rstrip().rstrip('}').rstrip()
        new_blk += '\n\n    # Use Let\'s Encrypt only (disable ZeroSSL fallback)\n    acme_ca https://acme-v02.api.letsencrypt.org/directory\n}'
        txt = txt.replace(old_blk, new_blk, 1)
        changed = True
        print('  [done] acme_ca added to global block')
    else:
        print('  WARN: global block not found — acme_ca not added')
else:
    print('  [skip] acme_ca already present')

# 2. localhost health block
if 'localhost {' not in txt:
    txt += """

# =============================================================================
# Internal health probe — tls internal self-signed cert for localhost.
# curl -sk https://localhost/status  ->  HTTP 200
# =============================================================================
localhost {
    tls internal

    handle /status {
        respond "OK" 200
    }

    respond 404
}
"""
    changed = True
    print('  [done] localhost block appended')
else:
    print('  [skip] localhost block already present')

if changed:
    with open(cf, 'w') as f:
        f.write(txt)

# Verify
with open(cf) as f:
    v = f.read()
ok = 'acme_ca https://acme-v02.api.letsencrypt.org/directory' in v and 'localhost {' in v
print('  [OK] Caddyfile verified' if ok else '  [ERROR] verification failed')
PYEOF

echo "  Validating cvg-caddy config..."
ssh ${SOPTS} -i "${SSH_KEY}" "ubuntu@10.10.10.200" \
    "docker exec cvg-caddy caddy validate --config /etc/caddy/Caddyfile 2>&1 | grep -E '(Valid|error)' | head -3"

echo "  Reloading cvg-caddy..."
ssh ${SOPTS} -i "${SSH_KEY}" "ubuntu@10.10.10.200" \
    "docker exec cvg-caddy caddy reload --config /etc/caddy/Caddyfile 2>&1 | grep -iE '(reload|error)' | head -3 || true"
sleep 3

echo "  Testing HTTPS /status on VM451..."
CODE=$(ssh ${SOPTS} -i "${SSH_KEY}" "ubuntu@10.10.10.200" \
    "docker exec cvg-caddy curl -sk --connect-timeout 8 -o /dev/null -w '%{http_code}' https://localhost/status 2>/dev/null" 2>/dev/null || echo "ERR")
echo "  HTTPS /status: HTTP ${CODE}"

CODE2=$(ssh ${SOPTS} -i "${SSH_KEY}" "ubuntu@10.10.10.200" \
    "docker exec cvg-caddy curl -sf --connect-timeout 5 -o /dev/null -w '%{http_code}' http://localhost:2019/config/ 2>/dev/null" 2>/dev/null || echo "ERR")
echo "  Admin API: HTTP ${CODE2}"

echo ""
echo "Done. All Caddyfile patches applied."
