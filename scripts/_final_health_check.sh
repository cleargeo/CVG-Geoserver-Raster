#!/usr/bin/env bash
# _final_health_check.sh — Comprehensive final verification across all 5 VMs
# Corrected: uses docker exec for internal-only services; correct Caddyfile paths

K="$HOME/.ssh/cvg_neuron_proxmox"
O="-o StrictHostKeyChecking=no -o ConnectTimeout=10"

PASS=0; FAIL=0
ok()  { echo "  [✓] $*"; PASS=$((PASS+1)); }
err() { echo "  [✗] $*"; FAIL=$((FAIL+1)); }
warn(){ echo "  [~] $*"; }
section() {
  echo
  echo "══════════════════════════════════════════════"
  echo "  $*"
  echo "══════════════════════════════════════════════"
}

chk_http() {
  local label="$1" code="$2" expected="$3"
  if [[ "$code" == "$expected" ]]; then ok "$label → HTTP $code"
  else err "$label → HTTP $code (expected $expected)"; fi
}

ssh_run() {
  local ip="$1"; shift
  ssh -i "$K" $O ubuntu@"$ip" "$@" 2>&1
}

# ══════════════════════════════════════════════════════════════════════════════
section "VM454 — cvg-geoserver-raster-01 (10.10.10.203)"
IP=10.10.10.203
CF=/opt/cvg/CVG_Geoserver_Raster/caddy/Caddyfile

# Containers
for c in geoserver-raster caddy-gsr; do
  st=$(ssh_run $IP "docker inspect --format='{{.State.Status}}' $c 2>/dev/null || echo 'missing'")
  [[ "$st" == "running" ]] && ok "$c running" || err "$c state: $st"
done

# GeoServer OWS endpoints (via docker exec — port not host-bound)
for svc in "WMS&version=1.3.0" "WFS&version=2.0.0" "WCS&version=2.0.1"; do
  name="${svc%%&*}"
  code=$(ssh_run $IP "docker exec geoserver-raster curl -sf -o /dev/null -w '%{http_code}' \"http://localhost:8080/geoserver/ows?service=${svc}&request=GetCapabilities\" 2>/dev/null || echo 'ERR'")
  chk_http "GeoServer $name GetCapabilities" "$code" "200"
done

# WFS encoding in XML body
enc=$(ssh_run $IP "docker exec geoserver-raster curl -s \"http://localhost:8080/geoserver/ows?service=WFS&version=2.0.0&request=GetCapabilities\" 2>/dev/null | grep -o 'encoding=\"[^\"]*\"' | head -1")
[[ "$enc" =~ UTF-8|utf-8 ]] && ok "WFS XML encoding: $enc" || err "WFS XML encoding not UTF-8: '$enc'"

# Caddy HTTPS /status (inside container — uses tls internal on localhost)
code=$(ssh_run $IP "docker exec caddy-gsr curl -sk -o /dev/null -w '%{http_code}' https://localhost/status 2>/dev/null || echo 'ERR'")
chk_http "Caddy HTTPS /status" "$code" "200"

# Caddy admin API
code=$(ssh_run $IP "docker exec caddy-gsr curl -sf -o /dev/null -w '%{http_code}' http://localhost:2019/config/ 2>/dev/null || echo 'ERR'")
chk_http "Caddy admin API" "$code" "200"

# acme_ca LE-only (active line, not commented)
acme=$(ssh_run $IP "grep 'acme_ca' $CF 2>/dev/null | grep -v '#' || true")
[[ "$acme" =~ letsencrypt ]] && ok "acme_ca → LE-only" || err "acme_ca not active in $CF"

# ══════════════════════════════════════════════════════════════════════════════
section "VM455 — cvg-geoserver-vector-01 (10.10.10.204)"
IP=10.10.10.204
CF=/opt/cvg/CVG_Geoserver_Vector/caddy/Caddyfile

for c in geoserver-vector caddy-gsv; do
  st=$(ssh_run $IP "docker inspect --format='{{.State.Status}}' $c 2>/dev/null || echo 'missing'")
  [[ "$st" == "running" ]] && ok "$c running" || err "$c state: $st"
done

for svc in "WMS&version=1.3.0" "WFS&version=2.0.0"; do
  name="${svc%%&*}"
  code=$(ssh_run $IP "docker exec geoserver-vector curl -sf -o /dev/null -w '%{http_code}' \"http://localhost:8080/geoserver/ows?service=${svc}&request=GetCapabilities\" 2>/dev/null || echo 'ERR'")
  chk_http "GeoServer $name GetCapabilities" "$code" "200"
done

enc=$(ssh_run $IP "docker exec geoserver-vector curl -s \"http://localhost:8080/geoserver/ows?service=WFS&version=2.0.0&request=GetCapabilities\" 2>/dev/null | grep -o 'encoding=\"[^\"]*\"' | head -1")
[[ "$enc" =~ UTF-8|utf-8 ]] && ok "WFS XML encoding: $enc" || err "WFS XML encoding not UTF-8: '$enc'"

code=$(ssh_run $IP "docker exec caddy-gsv curl -sk -o /dev/null -w '%{http_code}' https://localhost/status 2>/dev/null || echo 'ERR'")
chk_http "Caddy HTTPS /status" "$code" "200"

code=$(ssh_run $IP "docker exec caddy-gsv curl -sf -o /dev/null -w '%{http_code}' http://localhost:2019/config/ 2>/dev/null || echo 'ERR'")
chk_http "Caddy admin API" "$code" "200"

acme=$(ssh_run $IP "grep 'acme_ca' $CF 2>/dev/null | grep -v '#' || true")
[[ "$acme" =~ letsencrypt ]] && ok "acme_ca → LE-only" || err "acme_ca not active in $CF"

# ══════════════════════════════════════════════════════════════════════════════
section "VM451 — cvg-stormsurge-01 / Platform (10.10.10.200)"
IP=10.10.10.200
CF=/opt/cvg-platform/Caddyfile

for c in cvg-caddy cvg-neuron-v1 ssw-api; do
  st=$(ssh_run $IP "docker inspect --format='{{.State.Status}}' $c 2>/dev/null || echo 'missing'")
  [[ "$st" == "running" ]] && ok "$c running" || err "$c state: $st"
done

# ssw-api listens on port 8080 internally; /health returns 200
code=$(ssh_run $IP "docker exec ssw-api curl -sf -o /dev/null -w '%{http_code}' http://localhost:8080/health 2>/dev/null || echo 'ERR'")
chk_http "ssw-api /health" "$code" "200"

code=$(ssh_run $IP "docker exec cvg-caddy curl -sk -o /dev/null -w '%{http_code}' https://localhost/status 2>/dev/null || echo 'ERR'")
chk_http "Caddy HTTPS /status" "$code" "200"

code=$(ssh_run $IP "docker exec cvg-caddy curl -sf -o /dev/null -w '%{http_code}' http://localhost:2019/config/ 2>/dev/null || echo 'ERR'")
chk_http "Caddy admin API" "$code" "200"

acme=$(ssh_run $IP "sudo grep 'acme_ca' $CF 2>/dev/null | grep -v '#' || true")
[[ "$acme" =~ letsencrypt ]] && ok "acme_ca → LE-only" || err "acme_ca not active in $CF"

# ══════════════════════════════════════════════════════════════════════════════
section "VM452 — cvg-rainfall-01 (10.10.10.201)"
IP=10.10.10.201
CF=/opt/cvg/CVG_Rainfall_Wizard/caddy/Caddyfile

for c in rfw-api caddy-rfw; do
  st=$(ssh_run $IP "docker inspect --format='{{.State.Status}}' $c 2>/dev/null || echo 'missing'")
  [[ "$st" == "running" ]] && ok "$c running" || err "$c state: $st"
done

# rfw-api: Caddy routes to rainfall-wizard:8020 on Docker network; test from Caddy container
code=$(ssh_run $IP "docker exec caddy-rfw curl -sf -o /dev/null -w '%{http_code}' http://rainfall-wizard:8020/health 2>/dev/null || echo 'ERR'")
chk_http "rfw-api /health (via Caddy network)" "$code" "200"

code=$(ssh_run $IP "docker exec caddy-rfw curl -sk -o /dev/null -w '%{http_code}' https://localhost/status 2>/dev/null || echo 'ERR'")
chk_http "Caddy HTTPS /status" "$code" "200"

code=$(ssh_run $IP "docker exec caddy-rfw curl -sf -o /dev/null -w '%{http_code}' http://localhost:2019/config/ 2>/dev/null || echo 'ERR'")
chk_http "Caddy admin API" "$code" "200"

acme=$(ssh_run $IP "grep 'acme_ca' $CF 2>/dev/null | grep -v '#' || true")
[[ "$acme" =~ letsencrypt ]] && ok "acme_ca → LE-only" || err "acme_ca not active in $CF"

# ══════════════════════════════════════════════════════════════════════════════
section "VM453 — cvg-slr-01 (10.10.10.202)"
IP=10.10.10.202
CF=/opt/cvg/CVG_SLR_Wizard/caddy/Caddyfile

for c in slrw-api caddy-slrw; do
  st=$(ssh_run $IP "docker inspect --format='{{.State.Status}}' $c 2>/dev/null || echo 'missing'")
  [[ "$st" == "running" ]] && ok "$c running" || err "$c state: $st"
done

# slrw-api listens on port 8010 internally
code=$(ssh_run $IP "docker exec slrw-api curl -sf -o /dev/null -w '%{http_code}' http://localhost:8010/health 2>/dev/null || echo 'ERR'")
chk_http "slrw-api /health" "$code" "200"

code=$(ssh_run $IP "docker exec caddy-slrw curl -sk -o /dev/null -w '%{http_code}' https://localhost/status 2>/dev/null || echo 'ERR'")
chk_http "Caddy HTTPS /status" "$code" "200"

code=$(ssh_run $IP "docker exec caddy-slrw curl -sf -o /dev/null -w '%{http_code}' http://localhost:2019/config/ 2>/dev/null || echo 'ERR'")
chk_http "Caddy admin API" "$code" "200"

acme=$(ssh_run $IP "grep 'acme_ca' $CF 2>/dev/null | grep -v '#' || true")
[[ "$acme" =~ letsencrypt ]] && ok "acme_ca → LE-only" || err "acme_ca not active in $CF"

# ══════════════════════════════════════════════════════════════════════════════
section "SUMMARY"
TOTAL=$((PASS + FAIL))
echo "  Passed : $PASS / $TOTAL"
echo "  Failed : $FAIL / $TOTAL"
echo
if [[ $FAIL -eq 0 ]]; then
  echo "  ✅  ALL CHECKS PASSED — All 5 VMs healthy!"
else
  echo "  ⚠️   $FAIL check(s) need attention — see [✗] items above"
fi
echo
