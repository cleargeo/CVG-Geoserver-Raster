#!/usr/bin/env bash
# =============================================================================
# CVG GeoServer Raster â€” Admin Password Reset Script
# (c) Clearview Geographic, LLC â€” Proprietary
# =============================================================================
# Resets the GeoServer admin password via the REST API.
# Reads credentials from .env file or environment variables.
#
# Usage:
#   bash scripts/reset-password.sh                    # use .env file
#   bash scripts/reset-password.sh --local            # against localhost:8080
#   bash scripts/reset-password.sh --prod             # against raster.cleargeo.tech (LAN req.)
#   bash scripts/reset-password.sh --ip 10.10.10.203  # against specific IP
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[reset-pw]${NC} $*"; }
success() { echo -e "${GREEN}[reset-pw]${NC} âœ“ $*"; }
warn()    { echo -e "${YELLOW}[reset-pw]${NC} âš  $*"; }
error()   { echo -e "${RED}[reset-pw]${NC} âœ— $*" >&2; exit 1; }

MODE="auto"
CUSTOM_IP=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --local)  MODE="local" ;;
        --prod)   MODE="prod" ;;
        --ip)     shift; CUSTOM_IP="${1:-}"; MODE="custom" ;;
        --ip=*)   CUSTOM_IP="${1#--ip=}"; MODE="custom" ;;
        *) ;;
    esac
    shift
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [[ -f "${ENV_FILE}" ]]; then
    info "Loading .env from ${ENV_FILE}"
    while IFS='=' read -r key value; do
        [[ "${key}" =~ ^[A-Z_][A-Z0-9_]*$ ]] || continue
        [[ -z "${value}" ]] && continue
        value="${value%\"}"; value="${value#\"}"; value="${value%\'}"; value="${value#\'}"
        export "${key}=${value}"
    done < <(grep -E '^[A-Z_][A-Z0-9_]*=' "${ENV_FILE}" 2>/dev/null || true)
fi

GS_USER="${GEOSERVER_ADMIN_USER:-admin}"
GS_NEW_PASS="${GEOSERVER_ADMIN_PASSWORD:-}"
GS_OLD_PASS="${GS_OLD_PASSWORD:-geoserver}"

[[ -n "${GS_NEW_PASS}" ]] || error "GEOSERVER_ADMIN_PASSWORD is not set. Add it to .env."

if [[ "${MODE}" == "auto" ]]; then
    if curl -fsS --connect-timeout 3 --max-time 3 "http://localhost:8080/geoserver/ows" > /dev/null 2>&1; then
        MODE="local"
    else
        MODE="prod"
    fi
fi

case "${MODE}" in
    local)  GS_URL="http://localhost:8080/geoserver" ;;
    prod)   GS_URL="https://raster.cleargeo.tech/geoserver" ;;
    custom) GS_URL="http://${CUSTOM_IP}:8080/geoserver" ;;
esac

info "CVG GeoServer Raster â€” Password Reset"
info "Target: ${GS_URL}"
info "User:   ${GS_USER}"

info "Verifying current credentials..."
HTTP_STATUS=$(curl -sk --connect-timeout 15 --max-time 15 \
    -u "${GS_USER}:${GS_OLD_PASS}" -o /dev/null -w "%{http_code}" \
    "${GS_URL}/rest/about/version.json" 2>/dev/null || echo "000")

if [[ "${HTTP_STATUS}" == "200" ]]; then
    info "Current credentials verified"
elif [[ "${HTTP_STATUS}" == "401" ]]; then
    HTTP_STATUS2=$(curl -sk --connect-timeout 15 --max-time 15 \
        -u "${GS_USER}:${GS_NEW_PASS}" -o /dev/null -w "%{http_code}" \
        "${GS_URL}/rest/about/version.json" 2>/dev/null || echo "000")
    [[ "${HTTP_STATUS2}" == "200" ]] && { success "New password already set"; exit 0; }
    error "Authentication failed â€” check GS_OLD_PASSWORD env var"
elif [[ "${HTTP_STATUS}" == "000" ]]; then
    error "Cannot connect to GeoServer at ${GS_URL}"
else
    error "Unexpected HTTP ${HTTP_STATUS}"
fi

info "Setting new admin password..."
HTTP_CHANGE=$(curl -sk --connect-timeout 15 --max-time 15 \
    -u "${GS_USER}:${GS_OLD_PASS}" -X PUT \
    -H "Content-Type: application/json" \
    -d "{\"oldPassword\":\"${GS_OLD_PASS}\",\"newPassword\":\"${GS_NEW_PASS}\"}" \
    -o /dev/null -w "%{http_code}" \
    "${GS_URL}/rest/security/self/password" 2>/dev/null || echo "000")

[[ "${HTTP_CHANGE}" == "200" ]] || error "Password change failed (HTTP ${HTTP_CHANGE})"
success "Password changed successfully"

info "Verifying new password..."
HTTP_VERIFY=$(curl -sk --connect-timeout 15 --max-time 15 \
    -u "${GS_USER}:${GS_NEW_PASS}" -o /dev/null -w "%{http_code}" \
    "${GS_URL}/rest/about/version.json" 2>/dev/null || echo "000")

[[ "${HTTP_VERIFY}" == "200" ]] || error "New password verification failed (HTTP ${HTTP_VERIFY})"
success "New password verified"

echo ""
echo -e "${GREEN}â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${NC}"
echo -e "${GREEN}  CVG GeoServer Raster â€” Password Reset Complete${NC}"
echo -e "${GREEN}â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${NC}"
echo -e "  Target: ${GS_URL}"
echo -e "  User:   ${GS_USER}"
echo -e "  Status: Password updated and verified"
echo ""
info "Admin UI: ${GS_URL}/web/"
