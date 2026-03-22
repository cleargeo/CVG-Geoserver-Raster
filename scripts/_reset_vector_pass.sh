#!/usr/bin/env bash
# Reset GeoServer admin password on VM455 (Vector) — same issue as VM454.
# GeoServer 2.24+ generates a random admin password on first data-dir creation.
SSH_KEY="${HOME}/.ssh/cvg_neuron_proxmox"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR)

NEW_ADMIN_PASS="geoserver"

echo "═══════════════════════════════════════════════════════"
echo "  Resetting GeoServer admin password on VM455 Vector"
echo "═══════════════════════════════════════════════════════"

ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" ubuntu@10.10.10.204 bash << REMOTE
set -euo pipefail
NEW_PASS="${NEW_ADMIN_PASS}"

echo ""
echo "=== 1. Check current REST API (may already work or be random) ==="
HTTP_CODE=\$(docker exec geoserver-vector curl -sS -o /dev/null -w "%{http_code}" \
  -u "admin:\${NEW_PASS}" --max-time 8 \
  "http://localhost:8080/geoserver/rest/about/version.json" 2>&1)
echo "  admin:\${NEW_PASS} → HTTP \${HTTP_CODE}"

if [[ "\${HTTP_CODE}" == "200" ]]; then
  echo "  ✓ Password is already geoserver — no reset needed"
  exit 0
fi

echo ""
echo "=== 2. Current users.xml hash ==="
docker exec geoserver-vector cat /opt/geoserver/data_dir/security/usergroup/default/users.xml 2>&1

echo ""
echo "=== 3. Overwrite users.xml with plain-text password ==="
docker exec geoserver-vector sh -c 'cat > /opt/geoserver/data_dir/security/usergroup/default/users.xml << '"'"'XML'"'"'
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<userRegistry xmlns="http://www.geoserver.org/security/users" version="1.0">
    <users>
        <user enabled="true" name="admin" password="plain:geoserver"/>
    </users>
    <groups/>
</userRegistry>
XML'
echo "  users.xml updated with plain:geoserver"

echo ""
echo "=== 4. Wait 15s for hot-reload ==="
sleep 15

echo ""
echo "=== 5. Verify REST API ==="
HTTP_CODE=\$(docker exec geoserver-vector curl -sS -o /dev/null -w "%{http_code}" \
  -u "admin:\${NEW_PASS}" --max-time 8 \
  "http://localhost:8080/geoserver/rest/about/version.json" 2>&1)
echo "  REST /rest/about/version.json → HTTP \${HTTP_CODE}"
[[ "\${HTTP_CODE}" == "200" ]] && echo "  ✓ REST API accessible!" || echo "  ✗ Still failing"

REMOTE

echo ""
echo "Done."
