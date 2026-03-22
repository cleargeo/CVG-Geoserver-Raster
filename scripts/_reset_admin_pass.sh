#!/usr/bin/env bash
# Reset GeoServer admin password to a known value.
# GeoServer 2.24+ generates a random admin password on first start — this
# script overwrites users.xml with plain:NEWPASS which GeoServer hot-reloads
# within 10 seconds (checkInterval=10000ms), then verifies REST API access.
SSH_KEY="${HOME}/.ssh/cvg_neuron_proxmox"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR)

# ── The new admin password we'll set (change this before running) ─────────────
# After reset it will be re-encoded as digest on next security reload.
NEW_ADMIN_PASS="geoserver"

echo "═══════════════════════════════════════════════════════"
echo "  Resetting GeoServer admin password on VM454 Raster"
echo "═══════════════════════════════════════════════════════"

ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" ubuntu@10.10.10.203 bash << REMOTE
set -euo pipefail

NEW_PASS="${NEW_ADMIN_PASS}"

echo ""
echo "=== 1. Search startup log for generated random password ==="
docker logs geoserver-raster 2>&1 | grep -iE "generat|random|initial.*pass|admin.*pass|pass.*admin|temp.*pass" | head -10 || echo "  (no generated password lines found in log)"

echo ""
echo "=== 2. Stop the failing init container (if still running) ==="
docker stop geoserver-raster-init 2>/dev/null && echo "  Init container stopped" || echo "  Init container not running"
docker rm geoserver-raster-init 2>/dev/null || true

echo ""
echo "=== 3. Overwrite users.xml with plain-text password ==="
# Write the new users.xml directly to the geoserver-data volume.
# GeoServer's XML service has checkInterval=10000ms — it will auto-reload.
docker exec geoserver-raster sh -c "cat > /opt/geoserver/data_dir/security/usergroup/default/users.xml << 'XML'
<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>
<userRegistry xmlns=\"http://www.geoserver.org/security/users\" version=\"1.0\">
    <users>
        <user enabled=\"true\" name=\"admin\" password=\"plain:\${NEW_PASS}\"/>
    </users>
    <groups/>
</userRegistry>
XML"
echo "  users.xml updated with plain:\${NEW_PASS}"

echo ""
echo "=== 4. Wait 15s for GeoServer to hot-reload users.xml ==="
sleep 15

echo ""
echo "=== 5. Verify REST API access with new password ==="
HTTP_CODE=\$(docker exec geoserver-raster curl -sS -o /dev/null -w "%{http_code}" \
  -u "admin:\${NEW_PASS}" --max-time 8 \
  "http://localhost:8080/geoserver/rest/about/version.json" 2>&1)
echo "  REST /rest/about/version.json → HTTP \${HTTP_CODE}"

if [[ "\${HTTP_CODE}" == "200" ]]; then
  echo "  ✓ REST API now accessible!"
else
  echo "  ✗ Still failing — checking current users.xml..."
  docker exec geoserver-raster cat /opt/geoserver/data_dir/security/usergroup/default/users.xml
fi

REMOTE

echo ""
echo "Done."
