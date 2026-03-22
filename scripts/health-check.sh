#!/usr/bin/env bash
# =============================================================================
# CVG GeoServer Raster â€” Comprehensive Health Check Script
# (c) Clearview Geographic, LLC â€” Proprietary
# =============================================================================
# Usage:
#   bash scripts/health-check.sh             # auto-detect local or prod
#   bash scripts/health-check.sh --local     # check dev stack (localhost)
#   bash scripts/health-check.sh --prod      # check production (raster.cleargeo.tech)
#   bash scripts/health-check.sh --ip <ip>   # check specific IP (port 8080)
#
# Exit codes:
#   0 â€” all critical checks passed
#   1 â€” one or more critical checks failed
# =============================================================================

set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

pass()  { echo -e "  ${GREEN}âœ“${NC} $*"; }
fail()  { echo -e "  ${RED}âœ—${NC} $*"; }
warn()  { echo -e "  ${YELLOW}âš ${NC} $*"; }
info()  { echo -e "  ${BLUE}â„¹${NC} $*"; }
title() { echo -e "\n${CYAN}${BOLD}â”€â”€ $* â”€â”€${NC}"; }

FAILURES=0
WARNINGS=0

check_http() {
    local label="$1" url="$2" expected_status="${3:-200}" timeout="${4:-15}"
    local actual_status
    actual_status=$(curl -sk --connect-timeout "${timeout}" --max-time "${timeout}" \
        -o /dev/null -w "%{http_code}" "${url}" 2>/dev/null || echo "000")

    if [[ "${actual_status}" == "${expected_status}" ]] || \
       [[ "${expected_status}" == "2xx" && "${actual_status}" =~ ^2 ]] || \
       [[ "${expected_status}" == "any" && "${actual_status}" != "000" ]]; then
        pass "${label} (HTTP ${actual_status})"
        return 0
    elif [[ "${actual_status}" == "000" ]]; then
        fail "${label} â€” UNREACHABLE"
        FAILURES=$((FAILURES + 1))
        return 1
    else
        fail "${label} â€” HTTP ${actual_status} (expected ${expected_status})"
        FAILURES=$((FAILURES + 1))
        return 1
    fi
}

check_content() {
    local label="$1" url="$2" pattern="$3" timeout="${4:-20}"
    local body
    body=$(curl -sk --connect-timeout "${timeout}" --max-time "${timeout}" "${url}" 2>/dev/null || echo "")
    if echo "${body}" | grep -qi "${pattern}"; then
        pass "${label} (content verified)"
        return 0
    elif [[ -z "${body}" ]]; then
        fail "${label} â€” No response"
        FAILURES=$((FAILURES + 1))
        return 1
    else
        fail "${label} â€” Content mismatch (pattern '${pattern}' not found)"
        FAILURES=$((FAILURES + 1))
        return 1
    fi
}

check_docker_container() {
    local name="$1" expected_status="${2:-running}"
    if ! command -v docker &>/dev/null; then
        warn "Docker not available â€” skipping container check"
        return 0
    fi
    local status
    status=$(docker inspect --format='{{.State.Status}}' "${name}" 2>/dev/null || echo "not_found")
    if [[ "${status}" == "${expected_status}" ]]; then
        local health
        health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}N/A{{end}}' "${name}" 2>/dev/null || echo "N/A")
        pass "Container ${name} (${status}, health: ${health})"
        return 0
    elif [[ "${status}" == "not_found" ]]; then
        warn "Container ${name} not found"
        WARNINGS=$((WARNINGS + 1))
        return 0
    else
        fail "Container ${name} â€” state: ${status}"
        FAILURES=$((FAILURES + 1))
        return 1
    fi
}

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

if [[ "${MODE}" == "auto" ]]; then
    if docker inspect geoserver-raster-dev &>/dev/null 2>&1; then
        MODE="local"
    else
        MODE="prod"
    fi
fi

case "${MODE}" in
    local)
        GS_BASE="http://localhost:8080/geoserver"
        PORTAL_BASE="http://localhost"
        MODE_LABEL="Local Dev (localhost)"
        ;;
    prod)
        GS_BASE="https://raster.cleargeo.tech/geoserver"
        PORTAL_BASE="https://raster.cleargeo.tech"
        MODE_LABEL="Production (raster.cleargeo.tech)"
        ;;
    custom)
        GS_BASE="http://${CUSTOM_IP}:8080/geoserver"
        PORTAL_BASE="http://${CUSTOM_IP}"
        MODE_LABEL="Custom (${CUSTOM_IP})"
        ;;
esac

echo ""
echo -e "${CYAN}${BOLD}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${NC}"
echo -e "${CYAN}${BOLD}â•‘   CVG GeoServer Raster â€” Health Check                    â•‘${NC}"
echo -e "${CYAN}${BOLD}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${NC}"
echo -e "  Mode:    ${BOLD}${MODE_LABEL}${NC}"
echo -e "  Time:    $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo -e "  Target:  ${GS_BASE}"

if [[ "${MODE}" == "local" ]]; then
    title "Docker Containers"
    check_docker_container "geoserver-raster-dev" "running"
    check_docker_container "caddy-gsr-dev" "running"
fi

title "Portal Page"
check_content "CVG Vector Data Portal" \
    "${PORTAL_BASE}/" \
    "Raster Data Services Portal" 20

title "GeoServer Core"
check_http "OWS Dispatcher" \
    "${GS_BASE}/ows" "any" 15

check_content "GeoServer Web UI" \
    "${GS_BASE}/web/" \
    "GeoServer" 15

title "WMS (Web Map Service)"
check_content "WMS GetCapabilities (v1.3.0)" \
    "${GS_BASE}/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities" \
    "WMS_Capabilities" 30

check_content "WMS GetCapabilities (v1.1.1)" \
    "${GS_BASE}/wms?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetCapabilities" \
    "WMT_MS_Capabilities\|WMS_Capabilities" 20

title "WCS (Web Coverage Service)"
check_content "WCS GetCapabilities (v2.0.1)" \
    "${GS_BASE}/wcs?SERVICE=WCS&VERSION=2.0.1&REQUEST=GetCapabilities" \
    "Capabilities" 30

check_content "WCS GetCapabilities (v1.1.1)" \
    "${GS_BASE}/wcs?SERVICE=WCS&VERSION=1.1.1&REQUEST=GetCapabilities" \
    "Capabilities" 20

title "GeoWebCache (Tile Cache)"
check_content "GWC WMTS GetCapabilities" \
    "${GS_BASE}/gwc/service/wmts?REQUEST=GetCapabilities" \
    "Capabilities" 20

check_content "GWC TMS Service List" \
    "${GS_BASE}/gwc/service/tms/1.0.0" \
    "TileMapService\|TMS" 15

title "Security (Admin Route Protection)"
if [[ "${MODE}" == "prod" ]]; then
    REST_CODE=$(curl -sk --connect-timeout 10 --max-time 10 \
        -o /dev/null -w "%{http_code}" \
        "${PORTAL_BASE}/geoserver/rest/workspaces.json" 2>/dev/null || echo "000")
    if [[ "${REST_CODE}" == "403" ]]; then
        pass "REST API blocked externally (HTTP 403)"
    elif [[ "${REST_CODE}" == "401" ]]; then
        warn "REST API returns 401 â€” consider IP restriction on Caddy"
        WARNINGS=$((WARNINGS + 1))
    else
        fail "REST API not properly restricted (HTTP ${REST_CODE}) â€” should be 403"
        FAILURES=$((FAILURES + 1))
    fi

    ADMIN_CODE=$(curl -sk --connect-timeout 10 --max-time 10 \
        -o /dev/null -w "%{http_code}" \
        "${PORTAL_BASE}/geoserver/web/" 2>/dev/null || echo "000")
    if [[ "${ADMIN_CODE}" == "403" ]] || [[ "${ADMIN_CODE}" == "200" ]]; then
        pass "Admin UI route handled (HTTP ${ADMIN_CODE})"
    else
        warn "Admin UI HTTP ${ADMIN_CODE} â€” verify LAN restriction"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    info "Security checks skipped in local dev mode"
fi

if [[ "${MODE}" == "prod" ]]; then
    title "TLS Certificate"
    CERT_EXPIRY=$(echo | timeout 5 openssl s_client -connect raster.cleargeo.tech:443 \
        -servername raster.cleargeo.tech 2>/dev/null \
        | openssl x509 -noout -enddate 2>/dev/null \
        | cut -d= -f2 || echo "")

    if [[ -n "${CERT_EXPIRY}" ]]; then
        EXPIRY_EPOCH=$(date -d "${CERT_EXPIRY}" +%s 2>/dev/null || echo "0")
        NOW_EPOCH=$(date +%s)
        DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))

        if [[ ${DAYS_LEFT} -gt 30 ]]; then
            pass "TLS cert valid â€” expires ${CERT_EXPIRY} (~${DAYS_LEFT} days)"
        elif [[ ${DAYS_LEFT} -gt 7 ]]; then
            warn "TLS cert expires soon â€” ${DAYS_LEFT} days remaining"
            WARNINGS=$((WARNINGS + 1))
        else
            fail "TLS cert expires in ${DAYS_LEFT} days â€” URGENT"
            FAILURES=$((FAILURES + 1))
        fi
    else
        warn "Could not check TLS certificate expiry"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

echo ""
echo -e "${CYAN}${BOLD}â”€â”€ Summary â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€${NC}"

if [[ ${FAILURES} -eq 0 && ${WARNINGS} -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}ALL CHECKS PASSED${NC} â€” CVG GeoServer Raster is healthy"
elif [[ ${FAILURES} -eq 0 ]]; then
    echo -e "  ${YELLOW}${BOLD}PASSED WITH WARNINGS${NC} â€” ${WARNINGS} warning(s), 0 failures"
else
    echo -e "  ${RED}${BOLD}FAILED${NC} â€” ${FAILURES} failure(s), ${WARNINGS} warning(s)"
    echo ""
    echo -e "  Troubleshooting:"
    echo -e "    Logs (local):  make logs"
    echo -e "    Logs (prod):   make logs-prod"
    echo -e "    Container:     docker compose ps"
fi

echo ""
exit ${FAILURES}
