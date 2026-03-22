#!/usr/bin/env bash
# =============================================================================
# CVG GeoServer Raster â€” Data Directory Backup Script
# (c) Clearview Geographic, LLC â€” Proprietary
# =============================================================================
# Backs up the GeoServer data_dir (workspaces, stores, styles, security config)
# to a timestamped tarball. Rotates to keep the last N backups.
#
# Usage (run on the production VM inside the project directory):
#   bash scripts/backup.sh
#   bash scripts/backup.sh --dest /mnt/cgdp/backups
#   bash scripts/backup.sh --keep 14
#
# Cron (add on VM): 0 3 * * * cd /opt/cvg/CVG_Geoserver_Vector && bash scripts/backup.sh >> /var/log/geoserver/backup.log 2>&1
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[backup]${NC} $*"; }
success() { echo -e "${GREEN}[backup]${NC} âœ“ $*"; }
warn()    { echo -e "${YELLOW}[backup]${NC} âš  $*"; }
error()   { echo -e "${RED}[backup]${NC} âœ— $*"; exit 1; }

BACKUP_DEST="${BACKUP_DEST:-/mnt/cgdp/backups/geoserver-raster}"
KEEP_COUNT="${BACKUP_KEEP:-7}"
GS_DATA_VOLUME="geoserver-raster-data"
GS_CONTAINER="geoserver-raster"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_NAME="geoserver-raster-datadir_${TIMESTAMP}.tar.gz"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dest)   shift; BACKUP_DEST="$1" ;;
        --dest=*) BACKUP_DEST="${1#--dest=}" ;;
        --keep)   shift; KEEP_COUNT="$1" ;;
        --keep=*) KEEP_COUNT="${1#--keep=}" ;;
        *) ;;
    esac
    shift
done

BACKUP_PATH="${BACKUP_DEST}/${BACKUP_NAME}"

info "CVG GeoServer Raster â€” Backup starting"
info "Destination: ${BACKUP_DEST}"
info "Retention:   ${KEEP_COUNT} backups"
info "Timestamp:   ${TIMESTAMP}"

command -v docker &>/dev/null || error "Docker not found"

docker volume inspect "${GS_DATA_VOLUME}" &>/dev/null || \
    error "Docker volume '${GS_DATA_VOLUME}' not found â€” is the stack deployed?"

mkdir -p "${BACKUP_DEST}" || error "Cannot create backup directory: ${BACKUP_DEST}"

AVAIL_KB=$(df -k "${BACKUP_DEST}" | awk 'NR==2{print $4}')
if [[ ${AVAIL_KB} -lt 512000 ]]; then
    error "Insufficient disk space: ${AVAIL_KB}KB available (need 256MB+)"
fi
info "Available disk: $(df -h "${BACKUP_DEST}" | awk 'NR==2{print $4}')"

info "Creating backup: ${BACKUP_NAME}"

docker run --rm \
    --volume "${GS_DATA_VOLUME}:/data:ro" \
    --volume "${BACKUP_DEST}:/backup" \
    alpine:3 \
    tar czf "/backup/${BACKUP_NAME}" \
        --exclude='/data/logs' \
        --exclude='/data/tmp' \
        --exclude='/data/.cvg_init_done' \
        -C /data \
        . 2>/dev/null

[[ -f "${BACKUP_PATH}" ]] || error "Backup file not created"

BACKUP_SIZE=$(du -sh "${BACKUP_PATH}" | cut -f1)
success "Backup created: ${BACKUP_NAME} (${BACKUP_SIZE})"

info "Verifying backup integrity..."
if tar -tzf "${BACKUP_PATH}" > /dev/null 2>&1; then
    FILE_COUNT=$(tar -tzf "${BACKUP_PATH}" | wc -l)
    success "Backup verified â€” ${FILE_COUNT} files archived"
else
    error "Backup integrity check FAILED: ${BACKUP_PATH}"
fi

info "Rotating backups (keeping ${KEEP_COUNT} most recent)..."
BACKUP_COUNT=$(find "${BACKUP_DEST}" -name "geoserver-raster-datadir_*.tar.gz" | wc -l)
if [[ ${BACKUP_COUNT} -gt ${KEEP_COUNT} ]]; then
    DELETE_COUNT=$((BACKUP_COUNT - KEEP_COUNT))
    find "${BACKUP_DEST}" -name "geoserver-raster-datadir_*.tar.gz" \
        -printf '%T+ %p\n' | sort | head -n "${DELETE_COUNT}" | awk '{print $2}' | \
        while read -r f; do rm -f "${f}"; info "  Removed: $(basename "${f}")"; done
fi

MANIFEST="${BACKUP_DEST}/backup_manifest.txt"
{
    echo "CVG GeoServer Raster â€” Backup Manifest"
    echo "Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "Server:    $(hostname)"
    echo "Volume:    ${GS_DATA_VOLUME}"
    echo "---"
    find "${BACKUP_DEST}" -name "geoserver-raster-datadir_*.tar.gz" \
        -printf '%TY-%Tm-%Td %TH:%TM  %6s bytes  %f\n' | sort -r
} > "${MANIFEST}"

success "Manifest updated: ${MANIFEST}"

echo ""
echo -e "${GREEN}â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${NC}"
echo -e "${GREEN}  CVG GeoServer Raster â€” Backup Complete${NC}"
echo -e "${GREEN}â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${NC}"
echo -e "  File:     ${BACKUP_NAME}"
echo -e "  Size:     ${BACKUP_SIZE}"
echo -e "  Location: ${BACKUP_DEST}"
echo -e "  Retained: $(find "${BACKUP_DEST}" -name "*.tar.gz" | wc -l) / ${KEEP_COUNT} backups"
echo ""
info "To restore: docker run --rm -v geoserver-raster-data:/data -v ${BACKUP_DEST}:/backup alpine tar xzf /backup/${BACKUP_NAME} -C /data"
