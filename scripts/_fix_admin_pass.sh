#!/usr/bin/env bash
# Inspect GeoServer security store and reset admin password to a known value.
# GeoServer 2.24+ generates a random master password on first start — the
# default "geoserver" password is encoded with that master key, so the plain
# credential no longer works unless we reset it.
SSH_KEY="${HOME}/.ssh/cvg_neuron_proxmox"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR)

echo "═══════════════════════════════════════════════════════"
echo "  Fix GeoServer admin password — VM454 Raster (10.10.10.203)"
echo "═══════════════════════════════════════════════════════"

ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" ubuntu@10.10.10.203 bash << 'REMOTE'

echo ""
echo "=== 1. Current admin user record (users.xml) ==="
docker exec geoserver-raster cat /opt/geoserver/data_dir/security/usergroup/default/users.xml 2>&1

echo ""
echo "=== 2. Password digest algorithm ==="
docker exec geoserver-raster cat /opt/geoserver/data_dir/security/usergroup/default/config.xml 2>&1

echo ""
echo "=== 3. Master password hints (do NOT print actual master pw) ==="
docker exec geoserver-raster ls -la /opt/geoserver/data_dir/security/masterpw/ 2>&1

echo ""
echo "=== 4. Resetting admin password via users.xml hot-reload ==="
# GeoServer stores the password as a digest hash. We'll:
# 1. Generate a new SHA256 digest of 'CVGadmin2025!' using GeoServer's format
# 2. Write it to users.xml
# 3. Touch the file so GeoServer reloads it

# GeoServer 2.x encodes passwords as:
#   plain:PASSWORD       (plaintext — allowed if digest encoding disabled)
#   digest1:HASH         (SHA256 digest encoded with master key)
# 
# The safest reset is to stop GeoServer, update users.xml with plain:password,
# then set GEOSERVER_ADMIN_PASSWORD env var so GeoServer updates on restart.
#
# SAFER APPROACH: Use GeoServer 2.24+ env var reset.
# If GEOSERVER_ADMIN_USER and GEOSERVER_ADMIN_PASSWORD are set in the env,
# GeoServer will reset the admin password on startup automatically.

echo "[+] Checking if env var password override is active..."
docker exec geoserver-raster env | grep -i geoserver | grep -i pass || echo "  No GEOSERVER_ADMIN_PASSWORD in env"

echo ""
echo "=== 5. Check GeoServer startup log for password reset messages ==="
docker logs geoserver-raster 2>&1 | grep -i "admin\|password\|master\|secur" | head -20

REMOTE

echo ""
echo "Done."
