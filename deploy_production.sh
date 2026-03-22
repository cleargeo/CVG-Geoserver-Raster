#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# CVG GeoServer Raster — Production Deployment Script
# (c) Clearview Geographic, LLC — Proprietary
# ══════════════════════════════════════════════════════════════════════════════
# Target: VM 454 (cvg-geoserver-raster-01) — 10.10.10.203 — raster.cleargeo.tech
# Proxmox: CVG-QUEEN-11-PROXMOX (10.10.10.56)
#
# USAGE (from DFORGE-100 workstation Git Bash):
#   cd "G:/07_APPLICATIONS_TOOLS/CVG_Geoserver_Raster"
#
#   # Full first-time deployment (creates VM, bootstraps, builds, deploys):
#   bash deploy_production.sh
#
#   # Fast redeploy — skip VM creation/bootstrap, just rsync + rebuild + restart:
#   bash deploy_production.sh --redeploy
#
#   # Fast redeploy with forced Docker cache bust (rebuild from scratch):
#   bash deploy_production.sh --redeploy --no-cache
#
#   # Deploy to VM451 platform stack instead of dedicated VM454
#   # (uses existing VM451 Caddy at .231, no new VM needed):
#   bash deploy_production.sh --target vm451
#
# WHAT THIS DOES (full deploy):
#   1. Pre-flight checks (SSH key, Dockerfile, GeoServer zip present)
#   2. Provision VM 454 on Proxmox via API (Ubuntu 22.04 cloud-init)
#   3. Wait for VM to boot and SSH to become available
#   4. Bootstrap VM: Docker CE, CIFS tools, directory layout
#   5. Mount TrueNAS CGPS + CGDP shares
#   6. rsync project files to /opt/cvg/CVG_Geoserver_Raster on VM
#   7. Build + launch docker-compose.prod.yml stack
#   8. Health-check GeoServer WMS GetCapabilities + Caddy
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail
IFS=$'\n\t'

# ── Parse arguments ────────────────────────────────────────────────────────
REDEPLOY=false
NO_CACHE=false
TARGET="vm454"
RUN_INIT=false
TAIL_LOGS=false

# Use while+shift for correct parsing (for-loop shift doesn't work in bash)
while [[ $# -gt 0 ]]; do
    case "$1" in
        --redeploy)   REDEPLOY=true ;;
        --no-cache)   NO_CACHE=true ;;
        --target)     shift; TARGET="${1:-vm454}" ;;
        --target=*)   TARGET="${1#--target=}" ;;
        --init)       RUN_INIT=true ;;
        --logs)       TAIL_LOGS=true ;;
        --help|-h)
            echo "Usage: bash deploy_production.sh [--redeploy] [--no-cache] [--target vm454|vm451] [--init] [--logs]"
            echo "  --redeploy    Skip VM creation, just sync + rebuild + restart"
            echo "  --no-cache    Force Docker cache bust (full rebuild)"
            echo "  --target      Deployment target: vm454 (default) or vm451"
            echo "  --init        Run GeoServer init script after deploy (sets admin password, metadata)"
            echo "  --logs        Tail GeoServer logs after deploy"
            exit 0
            ;;
        *) warn "Unknown argument: $1" ;;
    esac
    shift
done

# ── Config ─────────────────────────────────────────────────────────────────
PROXMOX_HOST="10.10.10.56"
PROXMOX_NODE="CVG-QUEEN-11-PROXMOX"
VMID=454
VM_STATIC_IP="10.10.10.203"
VM_HOSTNAME="cvg-geoserver-raster-01"
VM_GW="10.10.10.1"
VM_DNS="8.8.8.8 1.1.1.1"
VM_RAM=32768     # 32 GB — raster tile caching + ImageMosaic heap
VM_CORES=8
VM_DISK_SIZE=100 # GB
DISK_POOL="PE-Enclosure1"

CI_USER="ubuntu"
CI_PASS="CVGadmin2026!"

# TrueNAS shares
TRUENAS_CGPS_SHARE="//10.10.10.100/cgps"
TRUENAS_CGDP_SHARE="//10.10.10.100/cgdp"
SMB_USER="ProcessingVM1"
SMB_PASS="CVGproc1!2026"
SMB_DOMAIN="WORKGROUP"

# Project
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DEST="/opt/cvg/CVG_Geoserver_Raster"

DOMAIN="cleargeo.tech"
SUBDOMAIN="raster"

# VM451 platform integration (--target vm451)
VM451_IP="10.10.10.200"
VM451_USER="ubuntu"
VM451_PLATFORM_DIR="/opt/cvg-platform"

# SSH
SSH_KEY="${HOME}/.ssh/cvg_neuron_proxmox"
# SSH options as a bash array — safe word-splitting on Windows/MSYS
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=30 -o ServerAliveInterval=15 -o LogLevel=ERROR)

# Proxmox API token
PVE_TOKEN="PVEAPIToken=root@pam!fulltoken=d0af97b6-36df-49e7-82dc-ed37a8c4f3ff"

# Cloud-init image
CLOUD_IMG="jammy-server-cloudimg-amd64.img"
CLOUD_IMG_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
TEMPLATE_VMID=9000

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
info() { echo -e "${BLUE}[i]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*"; exit 1; }
step() { echo -e "\n${CYAN}══ Step $1: $2 ══${NC}"; }

# Determine target IP based on deploy mode
if [[ "$TARGET" == "vm451" ]]; then
    DEPLOY_IP="$VM451_IP"
    DEPLOY_USER="$VM451_USER"
    PROJECT_DEST="$VM451_PLATFORM_DIR/geoserver-raster"
    info "Target: VM451 platform stack (${VM451_IP}) — no new VM provisioning needed"
    REDEPLOY=true   # VM451 already exists, treat as redeploy
else
    DEPLOY_IP="$VM_STATIC_IP"
    DEPLOY_USER="$CI_USER"
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 0: Pre-flight checks
# ══════════════════════════════════════════════════════════════════════════════

step 0 "Pre-flight checks"

[ -f "${SSH_KEY}" ]                                || err "SSH key not found: ${SSH_KEY}"
[ -f "${SCRIPT_DIR}/Dockerfile" ]                  || err "Dockerfile not found in ${SCRIPT_DIR}"
[ -f "${SCRIPT_DIR}/docker-compose.prod.yml" ]     || err "docker-compose.prod.yml not found"
[ -f "${SCRIPT_DIR}/geoserver-2.28.3-bin.zip" ]   || err "geoserver-2.28.3-bin.zip not found in ${SCRIPT_DIR}"

log "Script dir:   ${SCRIPT_DIR}"
log "Target:       ${TARGET} (${DEPLOY_IP})"
log "Public URL:   https://${SUBDOMAIN}.${DOMAIN}"
log "Redeploy:     ${REDEPLOY}"
log "Force build:  ${NO_CACHE}"

if [[ "$REDEPLOY" == false ]]; then

    # ══════════════════════════════════════════════════════════════════════════
    # STEP 1: Provision VM on Proxmox
    # ══════════════════════════════════════════════════════════════════════════

    step 1 "Provision VM ${VMID} on Proxmox ${PROXMOX_HOST}"

    VM_STATUS=$(curl -sk -H "Authorization: ${PVE_TOKEN}" \
        "https://${PROXMOX_HOST}:8006/api2/json/nodes/${PROXMOX_NODE}/qemu/${VMID}/status/current" \
        2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    print(d.get('data',{}).get('status','missing'))
except:
    print('missing')
" 2>/dev/null || echo "missing")

    info "VM ${VMID} status: ${VM_STATUS}"

    if [[ "${VM_STATUS}" == "missing" ]] || [[ -z "${VM_STATUS}" ]]; then

        PUB_KEY_FILE="${SSH_KEY}.pub"
        if [ -f "${PUB_KEY_FILE}" ]; then
            log "Uploading SSH public key to Proxmox..."
            scp ${SSH_OPTS} -i "${SSH_KEY}" "${PUB_KEY_FILE}" \
                "root@${PROXMOX_HOST}:/tmp/cvg_deploy_key_${VMID}.pub" 2>/dev/null \
                || warn "Could not upload SSH key — will use password auth"
        fi

        log "Creating VM ${VMID} on Proxmox..."
        ssh ${SSH_OPTS} -i "${SSH_KEY}" "root@${PROXMOX_HOST}" /bin/bash << PROXMOX_EOF

set -euo pipefail
VMID="${VMID}"
VM_NAME="${VM_HOSTNAME}"
VM_IP="${VM_STATIC_IP}"
VM_GW="${VM_GW}"
VM_DNS="${VM_DNS}"
VM_RAM="${VM_RAM}"
VM_CORES="${VM_CORES}"
VM_DISK="${VM_DISK_SIZE}"
DISK_POOL="${DISK_POOL}"
TEMPLATE="${TEMPLATE_VMID}"
CI_USER="${CI_USER}"
CI_PASS="${CI_PASS}"
PUB_KEY_FILE="/tmp/cvg_deploy_key_${VMID}.pub"

echo "[proxmox] === GeoServer Raster VM \$VMID ==="

# Ensure template VM exists
if ! qm status \$TEMPLATE &>/dev/null; then
    echo "[proxmox] Creating Ubuntu 22.04 cloud-init template (VMID \$TEMPLATE)..."
    IMG_PATH="/var/lib/vz/template/iso/${CLOUD_IMG}"
    if [ ! -f "\$IMG_PATH" ]; then
        echo "[proxmox] Downloading Ubuntu 22.04 cloud image..."
        wget -q --show-progress -O "\$IMG_PATH" "${CLOUD_IMG_URL}"
    fi
    qm create \$TEMPLATE --name ubuntu-2204-template \
        --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0 \
        --ostype l26 --scsihw virtio-scsi-single \
        --serial0 socket --vga serial0
    DISK_FILE=\$(qm importdisk \$TEMPLATE "\$IMG_PATH" "\$DISK_POOL" 2>&1 \
        | grep -o "vm-\${TEMPLATE}-disk-[0-9]*" | head -1)
    [ -z "\$DISK_FILE" ] && DISK_FILE="vm-\${TEMPLATE}-disk-0"
    qm set \$TEMPLATE --scsi0 \${DISK_POOL}:\${DISK_FILE} \
        --ide2 \${DISK_POOL}:cloudinit --boot c --bootdisk scsi0 --agent enabled=1
    qm template \$TEMPLATE
    echo "[proxmox] Template ready"
fi

echo "[proxmox] Cloning template \$TEMPLATE → VM \$VMID..."
qm clone \$TEMPLATE \$VMID --name "\$VM_NAME" --full

qm set \$VMID \
    --memory \$VM_RAM --balloon 0 --cores \$VM_CORES \
    --sockets 1 --cpu host --numa 1

qm resize \$VMID scsi0 \${VM_DISK}G

qm set \$VMID \
    --ipconfig0 "ip=\${VM_IP}/24,gw=\${VM_GW}" \
    --nameserver "\$VM_DNS" \
    --ciuser "\$CI_USER" \
    --cipassword "\$(openssl passwd -6 "\$CI_PASS")"

[ -f "\$PUB_KEY_FILE" ] && qm set \$VMID --sshkeys "\$PUB_KEY_FILE" && rm -f "\$PUB_KEY_FILE"

qm set \$VMID --description "CVG GeoServer Raster 2.28.3
URL: https://raster.cleargeo.tech
Services: WMS/WCS/WMTS raster tiles, ImageMosaic, GeoTIFF, COG
Created: \$(date -u +%Y-%m-%dT%H:%M:%SZ)"

qm start \$VMID
echo "[proxmox] VM \$VMID started"
PROXMOX_EOF

        log "VM ${VMID} created — waiting 90s for cloud-init boot..."
        sleep 90

    elif [[ "${VM_STATUS}" == "stopped" ]]; then
        log "VM ${VMID} stopped — starting..."
        curl -sk -X POST -H "Authorization: ${PVE_TOKEN}" \
            "https://${PROXMOX_HOST}:8006/api2/json/nodes/${PROXMOX_NODE}/qemu/${VMID}/status/start" \
            > /dev/null
        sleep 30
    else
        log "VM ${VMID} already running"
    fi

    # ══════════════════════════════════════════════════════════════════════════
    # STEP 2: Wait for SSH
    # ══════════════════════════════════════════════════════════════════════════

    step 2 "Wait for VM SSH (${DEPLOY_USER}@${DEPLOY_IP})"
    MAX_WAIT=300; ELAPSED=0
    until ssh ${SSH_OPTS} -i "${SSH_KEY}" "${DEPLOY_USER}@${DEPLOY_IP}" "echo ok" 2>/dev/null; do
        [ $ELAPSED -ge $MAX_WAIT ] && err "SSH unreachable after ${MAX_WAIT}s — check Proxmox console: https://${PROXMOX_HOST}:8006"
        printf "  waiting... (%ds/%ds)\r" "$ELAPSED" "$MAX_WAIT"
        sleep 10; ELAPSED=$((ELAPSED + 10))
    done
    echo ""
    log "SSH reachable"

    # ══════════════════════════════════════════════════════════════════════════
    # STEP 3: Bootstrap Docker + tools
    # ══════════════════════════════════════════════════════════════════════════

    step 3 "Bootstrap Docker + CIFS on VM"

    ssh ${SSH_OPTS} -i "${SSH_KEY}" "${DEPLOY_USER}@${DEPLOY_IP}" /bin/bash << 'VM_BOOTSTRAP'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "[vm] Updating packages..."
sudo apt-get update -qq && sudo apt-get upgrade -yq 2>/dev/null

echo "[vm] Installing runtime tools..."
sudo apt-get install -yq \
    curl wget git htop vim tmux rsync jq unzip \
    cifs-utils nfs-common ca-certificates

echo "[vm] Installing Docker CE..."
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker ubuntu
    sudo systemctl enable --now docker
fi
echo "[vm] Docker: $(docker --version)"

if ! docker compose version &>/dev/null; then
    sudo apt-get install -yq docker-compose-plugin
fi
echo "[vm] Compose: $(docker compose version)"

sudo mkdir -p /opt/cvg /mnt/cgps /mnt/cgdp /var/log/caddy /var/log/geoserver
sudo chown -R ubuntu:ubuntu /opt/cvg
echo "[vm] Bootstrap complete"
VM_BOOTSTRAP

    log "Bootstrap complete"

    # ══════════════════════════════════════════════════════════════════════════
    # STEP 4: Mount TrueNAS shares
    # ══════════════════════════════════════════════════════════════════════════

    step 4 "Mount TrueNAS CGPS + CGDP"

    ssh ${SSH_OPTS} -i "${SSH_KEY}" "${DEPLOY_USER}@${DEPLOY_IP}" /bin/bash << MOUNT_SCRIPT
set -euo pipefail

sudo mkdir -p /etc/smbcredentials
sudo tee /etc/smbcredentials/cgps > /dev/null << CREDEOF
username=${SMB_USER}
password=${SMB_PASS}
domain=${SMB_DOMAIN}
CREDEOF
sudo chmod 600 /etc/smbcredentials/cgps
sudo chown root:root /etc/smbcredentials/cgps

mountpoint -q /mnt/cgps || \
    sudo mount -t cifs "${TRUENAS_CGPS_SHARE}" /mnt/cgps \
        -o credentials=/etc/smbcredentials/cgps,vers=3.0,uid=1000,gid=1000,\
file_mode=0664,dir_mode=0775,_netdev \
        && echo "[vm] CGPS mounted at /mnt/cgps" \
        || echo "[vm] WARN: CGPS mount failed"

mountpoint -q /mnt/cgdp || \
    sudo mount -t cifs "${TRUENAS_CGDP_SHARE}" /mnt/cgdp \
        -o credentials=/etc/smbcredentials/cgps,vers=3.0,uid=1000,gid=1000,\
file_mode=0664,dir_mode=0775,_netdev \
        && echo "[vm] CGDP mounted at /mnt/cgdp" \
        || echo "[vm] WARN: CGDP mount failed"

if ! grep -q "cgps" /etc/fstab; then
    sudo tee -a /etc/fstab > /dev/null << FSTABEOF

# CVG TrueNAS shares — added by deploy_production.sh
${TRUENAS_CGPS_SHARE} /mnt/cgps cifs credentials=/etc/smbcredentials/cgps,vers=3.0,uid=1000,gid=1000,file_mode=0664,dir_mode=0775,soft,_netdev 0 0
${TRUENAS_CGDP_SHARE} /mnt/cgdp cifs credentials=/etc/smbcredentials/cgps,vers=3.0,uid=1000,gid=1000,file_mode=0664,dir_mode=0775,soft,_netdev 0 0
FSTABEOF
    echo "[vm] fstab entries added"
fi
MOUNT_SCRIPT

    log "CGPS/CGDP mounts configured"

fi  # end if [[ "$REDEPLOY" == false ]]

# ══════════════════════════════════════════════════════════════════════════════
# STEP 5: Sync project files
# ══════════════════════════════════════════════════════════════════════════════

step 5 "Sync ${SCRIPT_DIR} → ${DEPLOY_USER}@${DEPLOY_IP}:${PROJECT_DEST}"

log "Syncing project files via ssh+tar (geoserver-2.28.3-bin.zip ~117MB — may take ~90s)"

# Ensure destination directory exists on the VM
ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" "${DEPLOY_USER}@${DEPLOY_IP}" \
    "mkdir -p '${PROJECT_DEST}'"

# Stream a tar archive over SSH — no rsync needed (tar + ssh are in Git Bash)
(cd "${SCRIPT_DIR}" && tar czf - \
    --exclude='.git' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.pytest_cache' \
    --exclude='geoserver-2.28.3-war.zip' \
    . ) | \
ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" "${DEPLOY_USER}@${DEPLOY_IP}" \
    "cd '${PROJECT_DEST}' && tar xzf - && echo '[vm] Project extracted OK'"

log "Project synced"

# ── Sync .env file separately (not in tar to keep it explicit) ───────────────
if [[ -f "${SCRIPT_DIR}/.env" ]]; then
    log "Syncing .env to VM..."
    scp "${SSH_OPTS[@]}" -i "${SSH_KEY}" \
        "${SCRIPT_DIR}/.env" \
        "${DEPLOY_USER}@${DEPLOY_IP}:${PROJECT_DEST}/.env"
    log ".env synced"
else
    warn ".env not found locally — GeoServer will use default admin password"
    warn "Run: cp .env.example .env && vi .env   then redeploy with --redeploy"
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 6: Build + launch Docker stack
# ══════════════════════════════════════════════════════════════════════════════

step 6 "Build + launch production Docker stack"

BUILD_ARGS=""
if [[ "$NO_CACHE" == true ]]; then
    BUILD_ARGS="--no-cache"
    warn "Building with --no-cache (full rebuild — may take 5-10 minutes)"
else
    log "Building with layer cache (fast rebuild)"
fi

ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" "${DEPLOY_USER}@${DEPLOY_IP}" /bin/bash << DOCKER_SCRIPT
set -euo pipefail
cd "${PROJECT_DEST}"

echo "[vm] Ensuring log directories exist..."
sudo mkdir -p /var/log/geoserver /var/log/caddy
sudo chown 1001:1001 /var/log/geoserver 2>/dev/null || true

echo "[vm] Pulling base images..."
docker compose -f docker-compose.prod.yml pull --ignore-pull-failures 2>/dev/null || true

echo "[vm] Building GeoServer Raster image..."
docker compose -f docker-compose.prod.yml build ${BUILD_ARGS}

echo "[vm] Stopping existing containers gracefully..."
docker compose -f docker-compose.prod.yml down --timeout 60 --remove-orphans 2>/dev/null || true

echo "[vm] Starting services..."
docker compose -f docker-compose.prod.yml up -d

echo "[vm] Waiting 90s for GeoServer to initialize..."
sleep 90

echo "[vm] Container status:"
docker compose -f docker-compose.prod.yml ps

echo ""
echo "[vm] GeoServer startup log (last 20 lines):"
docker logs geoserver-raster 2>&1 | tail -20

echo ""
echo "[vm] Attempting WMS GetCapabilities..."
curl -fsS --connect-timeout 30 \
    "http://localhost:8080/geoserver/ows?service=wms&version=1.3.0&request=GetCapabilities" \
    | grep -o "<Title>.*</Title>" | head -3 \
    || echo "[vm] WARN: GeoServer not yet ready — may need another minute"
DOCKER_SCRIPT

log "Docker stack launched"

# ══════════════════════════════════════════════════════════════════════════════
# STEP 7: Health verification
# ══════════════════════════════════════════════════════════════════════════════

step 7 "Health verification"

check_svc() {
    local name=$1 url=$2
    local code
    code=$(curl -sk --connect-timeout 15 -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    if [[ "$code" =~ ^(200|301|302)$ ]]; then
        log "✓ ${name}: HTTP ${code}"
    else
        warn "✗ ${name}: HTTP ${code} — GeoServer may still be initializing (allow 2 min total)"
    fi
}

check_svc "GeoServer OWS"    "http://${DEPLOY_IP}:8080/geoserver/ows"
check_svc "GeoServer WMS"    "http://${DEPLOY_IP}:8080/geoserver/ows?service=wms&version=1.3.0&request=GetCapabilities"
check_svc "GeoServer web UI" "http://${DEPLOY_IP}:8080/geoserver/web/"
if [[ "$TARGET" != "vm451" ]]; then
    check_svc "Caddy HTTP→HTTPS"   "http://${DEPLOY_IP}:80/"
    check_svc "CVG Raster Portal"  "http://${DEPLOY_IP}:80/"
    # Check portal actually serves our custom page (not a bare Caddy 404)
    PORTAL_BODY=$(curl -sk --connect-timeout 10 --max-time 10 "http://${DEPLOY_IP}:80/" 2>/dev/null || echo "")
    if echo "${PORTAL_BODY}" | grep -qi "Raster Data Services Portal"; then
        log "✓ Portal page content verified — CVG branded portal is live"
    else
        warn "Portal page may not be serving correctly — check caddy logs"
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 8: Summary
# ══════════════════════════════════════════════════════════════════════════════

step 8 "Deployment Summary"

cat << SUMMARY

${GREEN}══════════════════════════════════════════════════════════════════${NC}
${GREEN}  CVG GeoServer Raster — Deployed Successfully!                   ${NC}
${GREEN}══════════════════════════════════════════════════════════════════${NC}

  Host:         ${DEPLOY_IP} (${VM_HOSTNAME})
  Project:      ${PROJECT_DEST}
  Public URL:   https://${SUBDOMAIN}.${DOMAIN}

  OGC Service Endpoints:
    WMS (map images)  → https://${SUBDOMAIN}.${DOMAIN}/geoserver/wms
    WCS (raster data) → https://${SUBDOMAIN}.${DOMAIN}/geoserver/wcs
    WMTS (tile cache) → https://${SUBDOMAIN}.${DOMAIN}/geoserver/gwc/service/wmts
    REST API          → https://${SUBDOMAIN}.${DOMAIN}/geoserver/rest/
    Admin UI (LAN)    → http://${DEPLOY_IP}:8080/geoserver/web/

  Default credentials (CHANGE IMMEDIATELY!):
    Username: admin  |  Password: geoserver
    → https://${SUBDOMAIN}.${DOMAIN}/geoserver/web/
    → Security → Users/Groups/Roles → admin → Edit

  Required manual steps:
    1. ⚠  DNS A record:  ${SUBDOMAIN}.${DOMAIN}  →  <public IP>
           (In CT104 BIND: ssh root@10.10.10.75, edit /etc/bind/db.cleargeo.tech)

    2. ⚠  FortiGate VIP (if dedicated VM route):
           External: <new-public-ip>:80+443  →  Internal: ${VM_STATIC_IP}:80+443

    3. ✎  Change GeoServer admin password (above URL)

    4. ✎  Configure data stores:
           ImageMosaic from /mnt/cgps raster datasets
           GeoTIFF individual files
           COG: use "cog://" path prefix in GeoTIFF store

    5. ✎  Add control-flow.properties to data_dir
           See: plugins/README.md for recommended settings

${CYAN}  Proxmox console: https://${PROXMOX_HOST}:8006 → VM ${VMID}${NC}
${CYAN}  Re-deploy:       bash deploy_production.sh --redeploy${NC}
${CYAN}  Init password:   bash deploy_production.sh --redeploy --init${NC}
${CYAN}  Health check:    bash scripts/health-check.sh --ip ${DEPLOY_IP}${NC}
${CYAN}  Backup:          bash scripts/backup.sh${NC}

SUMMARY

# ══════════════════════════════════════════════════════════════════════════════
# OPTIONAL STEP 9: Run GeoServer init (--init flag)
# ══════════════════════════════════════════════════════════════════════════════
if [[ "${RUN_INIT}" == true ]]; then
    step 9 "GeoServer First-Run Initialization"
    info "Running geoserver-init to set admin password + service metadata..."
    ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" "${DEPLOY_USER}@${DEPLOY_IP}" \
        "cd '${PROJECT_DEST}' && docker compose -f docker-compose.prod.yml --profile init up geoserver-init; echo '[init] Done'"
    log "Initialization complete"
fi

# ══════════════════════════════════════════════════════════════════════════════
# OPTIONAL STEP 10: Tail logs (--logs flag)
# ══════════════════════════════════════════════════════════════════════════════
if [[ "${TAIL_LOGS}" == true ]]; then
    step 10 "Tailing GeoServer logs (Ctrl+C to stop)"
    ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" "${DEPLOY_USER}@${DEPLOY_IP}" \
        "cd '${PROJECT_DEST}' && docker compose -f docker-compose.prod.yml logs -f geoserver-raster"
fi
