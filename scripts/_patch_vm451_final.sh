#!/usr/bin/env bash
# Patch VM451 /opt/cvg-platform/Caddyfile: add acme_ca + validate + reload
SSH_KEY="${HOME}/.ssh/cvg_neuron_proxmox"
SOPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=12 -o LogLevel=ERROR"

echo "── VM451: Patching acme_ca in /opt/cvg-platform/Caddyfile ──"

ssh ${SOPTS} -i "${SSH_KEY}" "ubuntu@10.10.10.200" "sudo python3 - /opt/cvg-platform/Caddyfile" << 'PYEOF'
import sys
CF = sys.argv[1]
NEEDLE = "acme_ca https://acme-v02.api.letsencrypt.org/directory"
with open(CF) as f:
    txt = f.read()
if NEEDLE in txt:
    print("  [skip] acme_ca already present")
    sys.exit(0)
EMAIL = "email organization-support@cleargeo.tech"
if EMAIL not in txt:
    print("  [ERROR] email line not found in Caddyfile")
    sys.exit(1)
txt = txt.replace(EMAIL,
    EMAIL + "\n    # Use LE only (disable ZeroSSL fallback)\n    " + NEEDLE, 1)
with open(CF, "w") as f:
    f.write(txt)
with open(CF) as f:
    v = f.read()
print("  [OK] acme_ca patched" if NEEDLE in v else "  [ERROR] verify failed")
PYEOF

echo "[validate] Checking Caddyfile syntax..."
ssh ${SOPTS} -i "${SSH_KEY}" "ubuntu@10.10.10.200" \
    "docker exec cvg-caddy caddy validate --config /etc/caddy/Caddyfile 2>&1 | grep -E '(Valid|ERROR|error)' | head -3"

echo "[reload] Reloading cvg-caddy..."
ssh ${SOPTS} -i "${SSH_KEY}" "ubuntu@10.10.10.200" \
    "docker exec cvg-caddy caddy reload --config /etc/caddy/Caddyfile 2>&1 | grep -iE '(reload|error)' | head -3 || true"
sleep 3

echo "[test] HTTPS /status..."
CODE=$(ssh ${SOPTS} -i "${SSH_KEY}" "ubuntu@10.10.10.200" \
    "docker exec cvg-caddy curl -sk --connect-timeout 8 -o /dev/null -w '%{http_code}' https://localhost/status 2>/dev/null" 2>/dev/null || echo "ERR")
echo "  HTTPS /status: HTTP ${CODE}"

echo "[verify] acme_ca in live config..."
ssh ${SOPTS} -i "${SSH_KEY}" "ubuntu@10.10.10.200" \
    "sudo grep 'acme_ca' /opt/cvg-platform/Caddyfile && echo '  confirmed in file' || echo '  NOT in file'"

echo "Done."
