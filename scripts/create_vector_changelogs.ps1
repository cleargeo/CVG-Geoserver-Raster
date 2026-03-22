# create_vector_changelogs.ps1 - Create Vector 05_ChangeLogs/master_changelog.md + version_manifest.yml

$dir = 'G:\07_APPLICATIONS_TOOLS\CVG_Geoserver_Vector\05_ChangeLogs'
[System.IO.Directory]::CreateDirectory($dir) | Out-Null
Write-Host "Directory: $dir"

# ── master_changelog.md ─────────────────────────────────────────────────────
$mcPath = "$dir\master_changelog.md"
$mc = @'
# CVG GeoServer Vector — Master Changelog

**Project:** CVG GeoServer Vector
**Standard:** `Z:\9999\Cline_Global_Rules\Change Log Requirements.md`
**(c) Clearview Geographic LLC — All Rights Reserved**

---

## Deployment Log

| Date | Version | ChangeID | Author | VM | Summary |
|------|---------|----------|--------|----|---------|
| 2026-03-22 | v1.1.0 | 20260322-AZ-v1.1.0 | Alex Zelenski | VM 455 | Caddyfile hardening; 4 new operational scripts; HTTPS routing fixes; both GeoServer services verified live |
| 2026-03-21 | v1.0.0 | 20260321-AZ-v1.0.0 | Alex Zelenski | VM 455 (10.10.10.204) | Initial project scaffolding — multi-stage Dockerfile, plugin system, tini, container JVM, Caddy TLS, deploy script |

---

## v1.1.0 — 2026-03-22 — Caddyfile Hardening + Operational Scripts + Routing Fixes

**ChangeID:** `20260322-AZ-v1.1.0`
**Author:** Alex Zelenski, GISP
**Session:** 11/12 (continued from Sessions 10/11 on 2026-03-21)

### Files Added

| File | Role | Notes |
|------|------|-------|
| `scripts/geoserver-init.sh` | First-run init | REST API: set admin password, proxy URL, remove demo workspaces, create `cvg` workspace; sentinel file |
| `scripts/health-check.sh` | Health check | --local/--prod/--ip modes; WFS+WMS+WMTS+GWC; LAN restriction verify; TLS cert expiry; exit code 1 on failure |
| `scripts/backup.sh` | data_dir backup | `geoserver-vector-data` volume backup via ephemeral alpine; timestamped tarballs; --dest/--keep; manifest |
| `scripts/reset-password.sh` | Password reset | REST API password change; reads .env; auto-detect mode; verify old+new |
| `_check_status.bat` | Windows status | SSH launcher for cross-VM (VM454+VM455) Docker + WFS/WMS health check |
| `_check_status.sh` | Linux status | SSH to VM454+VM455; docker ps + WFS/WMS/Web UI health checks |

### Files Modified

| File | Change | Notes |
|------|--------|-------|
| `caddy/Caddyfile` | Major hardening | Portal landing; /health probe; WPS LAN restriction; OGC API route; HTTP block for VM451; trusted_proxies; cache headers; CSP; handle_errors implemented |
| `CHANGELOG.md` | Updated | v1.1.0 section added |
| `ROADMAP.md` | Updated | v0.3.0 marked complete; session history updated |
| `05_ChangeLogs/master_changelog.md` | Created | This file |
| `05_ChangeLogs/version_manifest.yml` | Created | v1.1.0; script entries; file versions tracked |

### Portal Enhancements (Session 12 — 2026-03-22)

| Feature | Detail |
|---------|--------|
| Basemap switcher | CartoDB Dark, OpenStreetMap, ESRI Satellite, OpenTopoMap |
| Opacity slider | Real-time WMS layer transparency (range 0–1) |
| Live GetMap URL bar | Updates on pan/zoom; one-click copy; visible when layer loaded |
| GetFeatureInfo on click | Fetches WFS JSON; renders feature properties popup (up to 8 fields) |

### Infrastructure Events

```
VM 454 (raster.cleargeo.tech) — HTTP routing chain VERIFIED LIVE:
  fix: VM451 cvg-caddy proxy target raster → http://10.10.10.203:80 (was :8080 directly)
  fix: VM451 health_uri /status removed (Host header mismatch → 308 → 503 cascade)
  fix: caddy/Caddyfile handle /status moved before reverse_proxy catch-all

VM 455 (vector.cleargeo.tech) — Same routing fixes applied on VM451 side

Verified production endpoints:
  https://raster.cleargeo.tech/status                              → "OK" 200 ✅
  https://raster.cleargeo.tech/geoserver/ows?service=WMS&...      → WMS_Capabilities 200 ✅
  https://vector.cleargeo.tech/status                             → "OK" 200 ✅
  https://vector.cleargeo.tech/geoserver/ows?service=WFS&...      → WFS_Capabilities 200 ✅
```

### Post-Deploy Checklist (v1.1.0)

- [x] DNS A record: `vector.cleargeo.tech → 131.148.52.225`
- [x] FortiGate VIP: `public:80+443 → 10.10.10.204:80+443`
- [x] HTTPS routing verified end-to-end via VM451
- [x] WFS GetCapabilities returning 200
- [ ] Run `scripts/geoserver-init.sh` to set admin password + `PROXY_BASE_URL` + create `cvg` workspace
- [ ] Configure PostGIS datastore: `jdbc:postgresql://10.10.10.XXX:5432/cvg_spatial`
- [ ] Verify `PROXY_BASE_URL` appears correctly in WFS GetCapabilities `OnlineResource` URLs
- [ ] Add `GEOSERVER_ADMIN_PASSWORD` to `.env` file on VM 455

---

## v1.0.0 — 2026-03-21 — Initial Release

**ChangeID:** `20260321-AZ-v1.0.0`
**Author:** Alex Zelenski, GISP
**Session:** 7

### Files Created

| File | Role | Notes |
|------|------|-------|
| `Dockerfile` | Container build | Multi-stage: extract+runtime; tini PID1; vector libs (geos/proj/spatialindex); container JVM; plugin installer |
| `docker-compose.yml` | Dev compose | Port 8080 exposed; dev image tag; localhost CSRF/PROXY |
| `docker-compose.prod.yml` | Prod compose | mem_limit:6g; cpus:3.0; ulimits; service_healthy; GWC volume; json logs |
| `caddy/Caddyfile` | Reverse proxy | Auto-HTTPS; CORS; security headers; max_body 50mb; WFS streaming flush; JSON log |
| `deploy_production.sh` | VM provisioning | VM 455 cloud-init; Docker bootstrap; CIFS mounts; rsync; build+launch |
| `.dockerignore` | Build exclusions | war.zip; docs; scripts; Caddy config; Python artifacts |
| `.gitignore` | SCM exclusions | data_dir; logs; secrets; OS files; Python artifacts |
| `plugins/README.md` | Plugin guide | Install instructions for GeoServer extension ZIPs |
| `README.md` | Documentation | Quick start; endpoints; data stores; infrastructure; security |
| `CHANGELOG.md` | History | This release + Unreleased section |
| `ROADMAP.md` | Planning | v1.0.0 → v2.0.0 milestones |
| `05_ChangeLogs/version_manifest.yml` | Version tracking | Per-file version + infrastructure metadata |
| `05_ChangeLogs/master_changelog.md` | Master log | This file |

### Infrastructure Summary

```
VM 455: cvg-geoserver-vector-01
  IP:    10.10.10.204 (Proxmox vmbr0, 10.10.10.0/24)
  RAM:   16 GB | vCPU: 4 | Disk: 60 GB (PE-Enclosure1 ZFS)
  URL:   https://vector.cleargeo.tech
  Stack: GeoServer 2.28.3 + Caddy 2-alpine + Watchtower
  JVM:   eclipse-temurin:17-jre-jammy | 4.2 GB heap (70% of 6 GB container limit)
  Data:  /mnt/cgps (CGPS TrueNAS, ro) + /mnt/cgdp (CGDP TrueNAS, ro)
```

### Endpoints Available After Deploy

| Endpoint | URL |
|----------|-----|
| WFS | `https://vector.cleargeo.tech/geoserver/wfs` |
| WMS | `https://vector.cleargeo.tech/geoserver/wms` |
| WMTS | `https://vector.cleargeo.tech/geoserver/gwc/service/wmts` |
| OGC API | `https://vector.cleargeo.tech/geoserver/ogc/features/v1` |
| REST API | `https://vector.cleargeo.tech/geoserver/rest` |
| Admin UI | `https://vector.cleargeo.tech/geoserver/web` |

### Post-Deploy Checklist

- [ ] DNS A record: `vector.cleargeo.tech → 131.148.52.225` (or dedicated VIP)
- [ ] FortiGate VIP: `public:80+443 → 10.10.10.204:80+443`
- [ ] Change GeoServer admin password (default: `admin/geoserver`)
- [ ] Configure data stores (Shapefile/GeoPackage from /mnt/cgps, PostGIS from internal DB)
- [ ] Verify `PROXY_BASE_URL` in GetCapabilities response URLs
- [ ] Seed GeoWebCache for baseline tile coverage
'@
[System.IO.File]::WriteAllText($mcPath, $mc, [System.Text.Encoding]::UTF8)
Write-Host "Written: $mcPath ($((Get-Item $mcPath).Length) bytes)"

# ── version_manifest.yml ────────────────────────────────────────────────────
$vmPath = "$dir\version_manifest.yml"
$vm = @'
# CVG GeoServer Vector — Version Manifest
# Standard: Z:/9999/Cline_Global_Rules/Change Log Requirements.md
# (c) Clearview Geographic LLC — All Rights Reserved

project: CVG GeoServer Vector
owner: Alex Zelenski, GISP
organization: Clearview Geographic, LLC
contact: azelenski@clearviewgeographic.com
website: https://www.clearviewgeographic.com
last_synced: "2026-03-22T06:00:00Z"
project_version: v1.1.0
change_id: 20260322-AZ-v1.1.0
last_deployment_note: "Session 12 — 2026-03-22 — Portal enhancements (basemap, opacity, GetMap URL bar, GetFeatureInfo); deployed to VM455 live"
license: Proprietary -- CVG-ADF

infrastructure:
  proxmox_host: 10.10.10.56
  proxmox_version: PVE 8.3.0
  target_vm: cvg-geoserver-vector-01 (VMID 455, 10.10.10.204)
  storage_pool: PE-Enclosure1 (ZFS)
  cgps_share: "//10.10.10.100/cgps"
  cgdp_share: "//10.10.10.100/cgdp"
  network: 10.10.10.0/24 (vmbr0)
  public_url: "https://vector.cleargeo.tech"

releases:
  - version: "1.1.0"
    date: "2026-03-22"
    change_id: "20260322-AZ-v1.1.0"
    summary: "Caddyfile hardening; 4 operational scripts (geoserver-init, health-check, backup, reset-password); _check_status scripts; portal enhancements (basemap, opacity, GetMap URL bar, GetFeatureInfo); HTTPS routing fixes; both GeoServer services verified live"
    breaking_changes: false
  - version: "1.0.0"
    date: "2026-03-21"
    change_id: "20260321-AZ-v1.0.0"
    summary: "Initial release — multi-stage Dockerfile, vector plugin system, tini, container JVM, Caddy TLS, VM 455 infra"
    breaking_changes: false

versions:
  Dockerfile:
    version: v1.0.0
    last_modified: "2026-03-21"
    author: Alex Zelenski
    status: final_reviewed
    notes: "Multi-stage build (extract+runtime), tini PID1, plugin installation system, container-aware JVM, vector libs (geos/proj/spatialindex), CSRF/PROXY vars"
  docker-compose.yml:
    version: v1.0.0
    last_modified: "2026-03-21"
    author: Alex Zelenski
    status: final_reviewed
    notes: "Local dev stack — bound :8080, dev image tag, PROXY_BASE_URL=localhost"
  docker-compose.prod.yml:
    version: v1.0.0
    last_modified: "2026-03-21"
    author: Alex Zelenski
    status: final_reviewed
    notes: "Prod stack — mem_limit:6g, cpus:3.0, ulimits nofile:32768, stop_grace_period:45s, service_healthy dep, GWC volume, json logging"
  caddy/Caddyfile:
    version: v1.1.0
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: final_reviewed
    notes: "v1.1.0: portal landing; /health probe; WPS LAN restriction; OGC API route; HTTP block for VM451; trusted_proxies; cache headers; CSP/Permissions-Policy/XSS headers; handle_errors implemented; handle /status ordering fixed; flush_interval -1 for WFS streaming"
  caddy/portal/index.html:
    version: v1.1.0
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: final_reviewed
    notes: "v1.1.0: basemap switcher (CartoDB Dark/OSM/ESRI Satellite/OpenTopo), opacity slider, live GetMap URL bar, WFS GetFeatureInfo on map click (JSON popup)"
  deploy_production.sh:
    version: v1.0.0
    last_modified: "2026-03-21"
    author: Alex Zelenski
    status: final_reviewed
    notes: "Full VM455 Proxmox bootstrap: cloud-init, Docker, CIFS mounts, rsync, compose build+launch"
  .dockerignore:
    version: v1.0.0
    last_modified: "2026-03-21"
    author: Alex Zelenski
    status: final_reviewed
  .gitignore:
    version: v1.0.0
    last_modified: "2026-03-21"
    author: Alex Zelenski
    status: final_reviewed
  README.md:
    version: v1.0.0
    last_modified: "2026-03-21"
    author: Alex Zelenski
    status: final_reviewed
    notes: "Quick start, endpoints, data stores, infrastructure reference, security notes"
  CHANGELOG.md:
    version: v1.1.0
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: final_reviewed
    notes: "v1.1.0 section + [Unreleased] portal improvements; WFS routing fixes; operational scripts"
  ROADMAP.md:
    version: v1.1.0
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: final_reviewed
    notes: "v0.3.0 marked complete (services live + portal); Session 12 added; v0.4.0 PostGIS next"
  05_ChangeLogs/version_manifest.yml:
    version: v1.1.0
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: final_reviewed
    notes: "This file — created v1.1.0: script entries, portal enhancements, file versions"
  05_ChangeLogs/master_changelog.md:
    version: v1.1.0
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: final_reviewed
    notes: "Created v1.1.0: routing fixes, scripts, portal enhancements with post-deploy checklist"
  scripts/geoserver-init.sh:
    version: v1.1.0
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: final_reviewed
    notes: "First-run init: sets admin password, proxy URL, removes demo workspaces, creates cvg workspace; idempotent sentinel"
  scripts/health-check.sh:
    version: v1.1.0
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: final_reviewed
    notes: "Comprehensive check: --local/--prod/--ip modes; containers; WFS+WMS+WMTS+GWC; LAN restriction; TLS cert expiry"
  scripts/backup.sh:
    version: v1.1.0
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: final_reviewed
    notes: "geoserver-vector-data volume backup via ephemeral alpine; timestamped tarballs; --dest/--keep; verify; manifest"
  scripts/reset-password.sh:
    version: v1.1.0
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: final_reviewed
    notes: "Admin password reset via REST API; reads .env; auto-detect local/prod; verifies old+new password"
  _check_status.bat:
    version: v1.1.0
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: final_reviewed
    notes: "Windows launcher: SSH to VM454+VM455, docker ps, WFS/WMS health checks"
  _check_status.sh:
    version: v1.1.0
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: final_reviewed
    notes: "Linux/bash: SSH to VM454+VM455, docker ps, WFS/WMS/Web health checks via curl"
'@
[System.IO.File]::WriteAllText($vmPath, $vm, [System.Text.Encoding]::UTF8)
Write-Host "Written: $vmPath ($((Get-Item $vmPath).Length) bytes)"

Write-Host "=== Vector 05_ChangeLogs files created ==="
