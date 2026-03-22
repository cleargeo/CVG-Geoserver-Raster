#!/usr/bin/env bash
# _fix_acme_caddyfiles.sh
# Add active acme_ca directive to VM454, VM455, VM452, VM453 Caddyfiles
# Uses python3 stdin pipe to avoid bash multiline argument split bugs
set -euo pipefail

K="$HOME/.ssh/cvg_neuron_proxmox"
O="-o StrictHostKeyChecking=no -o ConnectTimeout=10"

patch_acme() {
  local ip="$1" cfile="$2" caddy_container="$3" label="$4" use_sudo="${5:-false}"

  echo
  echo "── $label: Patching acme_ca in $cfile ──"

  local sudo_cmd=""
  [[ "$use_sudo" == "true" ]] && sudo_cmd="sudo"

  # Check if already patched (active, non-commented line)
  already=$(ssh -i "$K" $O ubuntu@"$ip" "$sudo_cmd grep -P '^\s+acme_ca\s' $cfile 2>/dev/null || true")
  if [[ "$already" =~ letsencrypt ]]; then
    echo "  [already] acme_ca already active: $already"
  else
    echo "  [patching] Adding acme_ca after email line..."
    ssh -i "$K" $O ubuntu@"$ip" "$sudo_cmd python3 - '$cfile'" << 'PYEOF'
import sys, os

fpath = sys.argv[1]
with open(fpath, 'r') as f:
    content = f.read()

target = '    email azelenski@clearviewgeographic.com'
insert = '    acme_ca https://acme-v02.api.letsencrypt.org/directory'

if insert in content:
    print("  [already] acme_ca line already present")
    sys.exit(0)

if target not in content:
    print(f"ERROR: email line not found in {fpath}", file=sys.stderr)
    sys.exit(1)

new = content.replace(target, f"{target}\n{insert}", 1)
with open(fpath, 'w') as f:
    f.write(new)
print(f"  [OK] acme_ca inserted after email line")
PYEOF
  fi

  # Verify
  result=$(ssh -i "$K" $O ubuntu@"$ip" "$sudo_cmd grep 'acme_ca' $cfile 2>/dev/null | grep -v '#' || true")
  if [[ "$result" =~ letsencrypt ]]; then
    echo "  [✓] acme_ca active: $result"
  else
    echo "  [✗] acme_ca not confirmed after patch! Full grep:"
    ssh -i "$K" $O ubuntu@"$ip" "$sudo_cmd grep 'acme_ca' $cfile 2>/dev/null || true"
    return 1
  fi

  # Validate + reload
  echo "  [validate] Checking Caddyfile syntax..."
  ssh -i "$K" $O ubuntu@"$ip" "docker exec $caddy_container caddy fmt --overwrite /etc/caddy/Caddyfile 2>/dev/null; docker exec $caddy_container caddy validate --config /etc/caddy/Caddyfile 2>&1" | grep -E 'Valid|Error|error' || true
  echo "  [reload] Reloading $caddy_container..."
  ssh -i "$K" $O ubuntu@"$ip" "docker exec $caddy_container caddy reload --config /etc/caddy/Caddyfile 2>&1" || true
  echo "  [done]"
}

# VM454 — /opt/cvg/CVG_Geoserver_Raster/caddy/Caddyfile
patch_acme 10.10.10.203 /opt/cvg/CVG_Geoserver_Raster/caddy/Caddyfile caddy-gsr "VM454 GeoServer Raster"

# VM455 — /opt/cvg/CVG_Geoserver_Vector/caddy/Caddyfile
patch_acme 10.10.10.204 /opt/cvg/CVG_Geoserver_Vector/caddy/Caddyfile caddy-gsv "VM455 GeoServer Vector"

# VM452 — /opt/cvg/CVG_Rainfall_Wizard/caddy/Caddyfile
patch_acme 10.10.10.201 /opt/cvg/CVG_Rainfall_Wizard/caddy/Caddyfile caddy-rfw "VM452 Rainfall Wizard"

# VM453 — /opt/cvg/CVG_SLR_Wizard/caddy/Caddyfile
patch_acme 10.10.10.202 /opt/cvg/CVG_SLR_Wizard/caddy/Caddyfile caddy-slrw "VM453 SLR Wizard"

echo
echo "══════════════════════════════════════════"
echo "  acme_ca patch complete on all 4 VMs"
echo "══════════════════════════════════════════"
