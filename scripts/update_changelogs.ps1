# update_changelogs.ps1 — CVG GeoServer changelog update (Session 12)
# Run: powershell -File scripts\update_changelogs.ps1

$enc = [System.Text.Encoding]::UTF8

# ─── RASTER master_changelog.md ─────────────────────────────────────────────
$rasterMasterCL = @'
# CVG GeoServer Raster — Master Changelog

**Project:** CVG GeoServer Raster
**Standard:** `Z:\9999\Cline_Global_Rules\Change Log Requirements.md`
**(c) Clearview Geographic LLC — All Rights Reserved**

---

## Deployment Log

| Date | Version | ChangeID | Author | VM | Summary |
|------|---------|----------|--------|----|---------|
| 2026-03-22 | [Unreleased] | 20260322-AZ-portal | Alex Zelenski | VM 454 | Session 12 — Portal enhancements live: basemap switcher, opacity slider, GetMap URL bar, WMS GetFeatureInfo on click |
| 2026-03-22 | v1.1.0 | 20260322-AZ-v1.1.0 | Alex Zelenski | VM 454 + VM 455 | Caddyfile hardening; 4 new operational scripts; HTTPS routing fixes; both GeoServer services verified live |
| 2026-03-21 | v1.0.0 | 20260321-AZ-v1.0.0 | Alex Zelenski | VM 454 (10.10.10.203) | Initial project scaffolding — multi-stage Dockerfile, plugin system, tini, container JVM, Caddy TLS, deploy script |

---

## [Unreleased] — Portal Enhancements — 2026-03-22 (Session 12)

**ChangeID:** `20260322-AZ-portal`
**Author:** Alex Zelenski, GISP
**Session:** 12

### Files Modified

| File | Change | Notes |
|------|--------|-------|
| `caddy/portal/index.html` | Major enhancements | Basemap switcher, opacity slider, live GetMap URL bar, WMS GetFeatureInfo pixel-value query on map click |

### Changes Detail

#### caddy/portal/index.html — Public Tool Additions
- **Basemap switcher** — `<select id="bmap-sel">` with CartoDB Dark (default), OpenStreetMap, ESRI Satellite, OpenTopoMap; `swBmap()` JS function swaps Leaflet tile layer without reloading the map
- **Opacity slider** — `<input type="range" id="osl">` with `setOp()` JS; adjusts WMS layer opacity in real time (0–100%); persists across layer changes
- **Live GetMap URL bar** — `<div id="gmap-bar">` below map; `updGMapUrl()` called on `moveend`/`zoomend`; shows full WMS GetMap URL for current view extent; one-click Copy button
- **WMS GetFeatureInfo on map click** — `map.on('click')` handler calls `GetFeatureInfo` with `INFO_FORMAT=text/html`; result displayed in floating popup anchored at click coordinates; queried via `raster.cleargeo.tech/geoserver/wms`
- **Scale bar** — Leaflet `L.control.scale()` added to map; shows metric + imperial units
- **`initMap()` function** — wraps map initialisation; called once on page load; handles basemap layer management

### Deployment

- Deployed to VM454 via SCP: `G:\...\caddy\portal\index.html` → `/opt/cvg/CVG_Geoserver_Raster/caddy/portal/index.html`
- Caddy bind-mounts `/opt/cvg/CVG_Geoserver_Raster/caddy/portal` → `/srv/portal`; changes are live immediately (no container restart required)
- Verified in browser at `https://raster.cleargeo.tech`

### Post-Deploy Checklist (Session 12)

- [x] Basemap switcher renders on portal load
- [x] Opacity slider adjusts WMS layer transparency
- [x] Live GetMap URL updates on pan/zoom
- [x] GetFeatureInfo popup appears on map click (when layer is loaded)
- [x] Deployed to VM454 and verified live
- [ ] Run `scripts/geoserver-init.sh` to set admin password + create `cvg` workspace
- [ ] Publish first raster layer so GetFeatureInfo can return real pixel values

---

## v1.1.0 — 2026-03-22 — Caddyfile Hardening + Operational Scripts + Routing Fixes

**ChangeID:** `20260322-AZ-v1.1.0`
**Author:** Alex Zelenski, GISP
**Session:** 11 (continued from Sessions 10/11 on 2026-03-21)

### Files Added

| File | Role | Notes |
|------|------|-------|
| `scripts/geoserver-init.sh` | First-run init | REST API: set admin password, proxy URL, remove demo workspaces, create `cvg` workspace; sentinel file |
| `scripts/health-check.sh` | Health check | --local/--prod/--ip modes; WMS+WCS+WMTS+GWC; LAN restriction verify; TLS cert expiry; exit code 1 on failure |
| `scripts/backup.sh` | data_dir backup | `geoserver-raster-data` volume backup via ephemeral alpine; timestamped tarballs; --dest/--keep; manifest |
| `scripts/reset-password.sh` | Password reset | REST API password change; reads .env; auto-detect mode; verify old+new |

### Files Modified

| File | Change | Notes |
|------|--------|-------|
| `caddy/Caddyfile` | Major hardening | Portal landing; /health probe; WPS LAN restriction; OGC API route; HTTP block for VM451; trusted_proxies; cache headers; CSP; handle_errors implemented |
| `CHANGELOG.md` | Updated | v1.1.0 section added |
| `ROADMAP.md` | Updated | v0.3.0 marked complete; session history updated |
| `05_ChangeLogs/master_changelog.md` | Updated | This file — v1.1.0 entry added |
| `05_ChangeLogs/version_manifest.yml` | Updated | v1.1.0; new script entries; updated file versions |

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

- [x] DNS A record: `raster.cleargeo.tech → 131.148.52.225`
- [x] FortiGate VIP: `public:80+443 → 10.10.10.203:80+443`
- [x] HTTPS routing verified end-to-end via VM451
- [x] WMS GetCapabilities returning 200
- [ ] Run `scripts/geoserver-init.sh` to set admin password + `PROXY_BASE_URL` + create `cvg` workspace
- [ ] Configure GeoTIFF/ImageMosaic data stores from `/mnt/cgps` + `/mnt/cgdp`
- [ ] Verify `PROXY_BASE_URL` appears correctly in WMS GetCapabilities `OnlineResource` URLs
- [ ] Seed GeoWebCache for baseline tile coverage

---

## v1.0.0 — 2026-03-21 — Initial Release

**ChangeID:** `20260321-AZ-v1.0.0`
**Author:** Alex Zelenski, GISP
**Session:** 6

### Files Created

| File | Role | Notes |
|------|------|-------|
| `Dockerfile` | Container build | Multi-stage: extract+runtime; tini PID1; GDAL; container JVM; plugin installer |
| `docker-compose.yml` | Dev compose | Port 8080 exposed; dev image tag; localhost CSRF/PROXY |
| `docker-compose.prod.yml` | Prod compose | mem_limit:8g; cpus:6.0; ulimits; service_healthy; GWC volume; json logs |
| `caddy/Caddyfile` | Reverse proxy | Auto-HTTPS; CORS; security headers; max_body 200mb; handle_errors; JSON log |
| `deploy_production.sh` | VM provisioning | VM 454 cloud-init; Docker bootstrap; CIFS mounts; rsync; build+launch |
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
VM 454: cvg-geoserver-raster-01
  IP:    10.10.10.203 (Proxmox vmbr0, 10.10.10.0/24)
  RAM:   32 GB | vCPU: 8 | Disk: 100 GB (PE-Enclosure1 ZFS)
  URL:   https://raster.cleargeo.tech
  Stack: GeoServer 2.28.3 + Caddy 2-alpine + Watchtower
  JVM:   eclipse-temurin:17-jre-jammy | 6 GB heap (75% of 8 GB container limit)
  Data:  /mnt/cgps (CGPS TrueNAS, ro) + /mnt/cgdp (CGDP TrueNAS, ro)
```

### Endpoints Available After Deploy

| Endpoint | URL |
|----------|-----|
| WMS | `https://raster.cleargeo.tech/geoserver/wms` |
| WCS | `https://raster.cleargeo.tech/geoserver/wcs` |
| WMTS | `https://raster.cleargeo.tech/geoserver/gwc/service/wmts` |
| TMS | `https://raster.cleargeo.tech/geoserver/gwc/service/tms/1.0.0` |
| REST API | `https://raster.cleargeo.tech/geoserver/rest` |
| Admin UI | `https://raster.cleargeo.tech/geoserver/web` |

### Post-Deploy Checklist

- [x] DNS A record: `raster.cleargeo.tech → 131.148.52.225` (or dedicated VIP)
- [x] FortiGate VIP: `public:80+443 → 10.10.10.203:80+443`
- [ ] Change GeoServer admin password (default: `admin/geoserver`)
- [ ] Configure data stores (GeoTIFF, ImageMosaic, COG from /mnt/cgps + /mnt/cgdp)
- [ ] Verify `PROXY_BASE_URL` in GetCapabilities response URLs
- [ ] Seed GeoWebCache for baseline tile coverage
'@

# ─── RASTER version_manifest.yml ────────────────────────────────────────────
$rasterManifest = @'
# CVG GeoServer Raster — Version Manifest
# Standard: Z:/9999/Cline_Global_Rules/Change Log Requirements.md
# (c) Clearview Geographic LLC — All Rights Reserved

project: CVG GeoServer Raster
owner: Alex Zelenski, GISP
organization: Clearview Geographic, LLC
contact: azelenski@clearviewgeographic.com
website: https://www.clearviewgeographic.com
last_synced: "2026-03-22T06:46:00Z"
project_version: v1.1.0
change_id: 20260322-AZ-portal
last_deployment_note: "Session 12 — 2026-03-22 — Portal enhancements: basemap switcher, opacity slider, GetMap URL bar, WMS GetFeatureInfo; deployed live to VM454"
license: Proprietary -- CVG-ADF

infrastructure:
  proxmox_host: 10.10.10.56
  proxmox_version: PVE 8.3.0
  target_vm: cvg-geoserver-raster-01 (VMID 454, 10.10.10.203)
  storage_pool: PE-Enclosure1 (ZFS)
  cgps_share: "//10.10.10.100/cgps"
  cgdp_share: "//10.10.10.100/cgdp"
  network: 10.10.10.0/24 (vmbr0)
  public_url: "https://raster.cleargeo.tech"

releases:
  - version: "unreleased"
    date: "2026-03-22"
    change_id: "20260322-AZ-portal"
    summary: "Session 12 portal enhancements: basemap switcher (CartoDB/OSM/ESRI Satellite/OpenTopo), opacity slider, live GetMap URL bar, WMS GetFeatureInfo pixel-value on click"
    breaking_changes: false
  - version: "1.1.0"
    date: "2026-03-22"
    change_id: "20260322-AZ-v1.1.0"
    summary: "Caddyfile hardening; 4 new operational scripts (geoserver-init, health-check, backup, reset-password); HTTPS routing fixes; both GeoServer services verified live"
    breaking_changes: false
  - version: "1.0.0"
    date: "2026-03-21"
    change_id: "20260321-AZ-v1.0.0"
    summary: "Initial release — multi-stage Dockerfile, plugin system, tini, container JVM, Caddy TLS, VM 454 infra"
    breaking_changes: false

versions:
  Dockerfile:
    version: v1.0.0
    last_modified: "2026-03-21"
    author: Alex Zelenski
    status: final_reviewed
    notes: "Multi-stage build (extract+runtime), tini PID1, plugin installation system, container-aware JVM, GDAL, CSRF/PROXY vars"
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
    notes: "Prod stack — mem_limit:8g, cpus:6.0, ulimits nofile:65536, service_healthy dep, GWC volume, json logging"
  caddy/Caddyfile:
    version: v1.1.0
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: final_reviewed
    notes: "v1.1.0: portal landing; /health probe; WPS LAN restriction; OGC API route; HTTP block for VM451; trusted_proxies; cache headers; CSP; handle_errors; /status ordering fixed"
  caddy/portal/index.html:
    version: v1.2.0-unreleased
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: deployed_live
    notes: "Session 12: basemap switcher (CartoDB/OSM/ESRI Satellite/OpenTopo), opacity slider, live GetMap URL bar, WMS GetFeatureInfo pixel-value on click, scale bar added to map"
  deploy_production.sh:
    version: v1.0.0
    last_modified: "2026-03-21"
    author: Alex Zelenski
    status: final_reviewed
    notes: "Full VM454 Proxmox bootstrap: cloud-init, Docker, CIFS mounts, rsync, compose build+launch"
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
    notes: "v1.1.0 section + [Unreleased] portal enhancement section (Session 12)"
  ROADMAP.md:
    version: v1.1.0
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: final_reviewed
    notes: "Session 12: v0.3.0 complete with portal; Next Steps; Current Live Status table; full v0.4.0-v1.0.0 with curl examples; Integration Matrix; Session History"
  scripts/control-flow.properties:
    version: v1.0.0
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: ready_to_deploy
    notes: "GeoServer control-flow plugin config: global=32, wms.getmap=16, wcs.getcoverage=4, user=6, timeout=120s; install to data_dir to activate"
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
    notes: "Comprehensive check: --local/--prod/--ip modes; containers; WMS+WCS+WMTS+GWC; LAN restriction; TLS cert expiry"
  scripts/backup.sh:
    version: v1.1.0
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: final_reviewed
    notes: "geoserver-raster-data volume backup via ephemeral alpine; timestamped tarballs; --dest/--keep; verify; manifest"
  scripts/reset-password.sh:
    version: v1.1.0
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: final_reviewed
    notes: "Admin password reset via REST API; reads .env; auto-detect local/prod; verifies old+new password"
  05_ChangeLogs/version_manifest.yml:
    version: v1.2.0-unreleased
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: final_reviewed
    notes: "This file — Session 12: portal/index.html and control-flow.properties entries added; unreleased release entry added"
  05_ChangeLogs/master_changelog.md:
    version: v1.2.0-unreleased
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: final_reviewed
    notes: "Session 12 [Unreleased] section added — portal enhancements + deployment note"
'@

# ─── VECTOR master_changelog.md ─────────────────────────────────────────────
$vectorMasterCL = @'
# CVG GeoServer Vector — Master Changelog

**Project:** CVG GeoServer Vector
**Standard:** `Z:\9999\Cline_Global_Rules\Change Log Requirements.md`
**(c) Clearview Geographic LLC — All Rights Reserved**

---

## Deployment Log

| Date | Version | ChangeID | Author | VM | Summary |
|------|---------|----------|--------|----|---------|
| 2026-03-22 | [Unreleased] | 20260322-AZ-portal-v | Alex Zelenski | VM 455 | Session 12 — Portal enhancements: basemap switcher, opacity slider, GetMap URL bar, WFS GetFeatureInfo JSON popup on click |
| 2026-03-22 | v1.1.0 | 20260322-AZ-v1.1.0-v | Alex Zelenski | VM 455 + VM 451 | HTTPS routing fixes; operational scripts formally tracked; cross-VM status checks; services verified live |
| 2026-03-21 | v1.0.0 | 20260321-AZ-v1.0.0-v | Alex Zelenski | VM 455 (10.10.10.204) | Initial project scaffolding — multi-stage Dockerfile, vectortiles/css/importer plugins, tini, container JVM, Caddy TLS, deploy script |

---

## [Unreleased] — Portal Enhancements — 2026-03-22 (Session 12)

**ChangeID:** `20260322-AZ-portal-v`
**Author:** Alex Zelenski, GISP
**Session:** 12

### Files Modified

| File | Change | Notes |
|------|--------|-------|
| `caddy/portal/index.html` | Major enhancements | Basemap switcher, opacity slider, live GetMap URL bar, WFS GetFeatureInfo JSON attribute popup on map click |

### Changes Detail

#### caddy/portal/index.html — Public Tool Additions
- **Basemap switcher** — `<select id="bmap-sel">` with CartoDB Dark (default), OpenStreetMap, ESRI Satellite, OpenTopoMap; `swBmap()` JS function swaps Leaflet tile layer without reloading the map
- **Opacity slider** — `<input type="range" id="osl">` with `setOp()` JS; adjusts WMS layer opacity in real time (0–100%); persists across layer changes
- **Live GetMap URL bar** — `<div id="gmap-bar">` below map; `updGMapUrl()` called on `moveend`/`zoomend`; shows full WMS GetMap URL for current view extent; one-click Copy button
- **WFS GetFeatureInfo on map click** — `map.on('click')` handler calls `GetFeatureInfo` with `INFO_FORMAT=application/json`; JSON response parsed; feature attributes displayed in floating popup; queried via `vector.cleargeo.tech/geoserver/wms`
- **Scale bar** — Leaflet `L.control.scale()` added to map; shows metric + imperial units
- **`initMap()` function** — wraps map initialisation; called once on page load; handles basemap layer management

### Deployment

- Deployed to VM455 via SCP: `G:\...\caddy\portal\index.html` → `/opt/cvg/CVG_Geoserver_Vector/caddy/portal/index.html`
- Caddy bind-mounts `/opt/cvg/CVG_Geoserver_Vector/caddy/portal` → `/srv/portal`; changes are live immediately (no container restart required)
- Verified in browser at `https://vector.cleargeo.tech`

### Post-Deploy Checklist (Session 12)

- [x] Basemap switcher renders on portal load
- [x] Opacity slider adjusts WMS/WFS layer transparency
- [x] Live GetMap URL updates on pan/zoom
- [x] GetFeatureInfo JSON popup appears on map click (when layer is loaded)
- [x] Deployed to VM455 and verified live
- [ ] Run `scripts/geoserver-init.sh` to set admin password + create `cvg` workspace
- [ ] Publish first vector layer so GetFeatureInfo can return real feature attributes

---

## v1.1.0 — 2026-03-22 — Routing Fixes + Operational Scripts

**ChangeID:** `20260322-AZ-v1.1.0-v`
**Author:** Alex Zelenski, GISP
**Session:** 11 (continued from Sessions 10/11 on 2026-03-21)

### Files Added

| File | Role | Notes |
|------|------|-------|
| `_check_status.bat` | Cross-VM status (Windows) | SSH to VM454+VM455; docker ps; internal WFS/WMS checks via docker exec; Caddy :80 |
| `_check_status.sh` | Cross-VM status (Unix) | Same checks as .bat; bash version for Linux/macOS |
| `scripts/geoserver-init.sh` | First-run init | REST API: set admin password, proxy URL, remove demo workspaces, create `cvg` workspace; sentinel file |
| `scripts/health-check.sh` | Health check | --local/--prod/--ip modes; WFS+WMS+WMTS+GWC; LAN restriction verify; TLS cert expiry; exit code 1 on failure |
| `scripts/backup.sh` | data_dir backup | `geoserver-vector-data` volume backup via ephemeral alpine; timestamped tarballs; --dest/--keep; manifest |
| `scripts/reset-password.sh` | Password reset | REST API password change; reads .env; auto-detect mode; verify old+new |

### Files Modified

| File | Change | Notes |
|------|--------|-------|
| `caddy/Caddyfile` | Major hardening | Portal landing; /health probe; WPS LAN restriction; OGC API route; trusted_proxies; cache headers; CSP; handle_errors; /status ordering fixed |
| `CHANGELOG.md` | Updated | v1.1.0 section added |
| `ROADMAP.md` | Updated | v0.3.0 marked complete; session history updated |
| `05_ChangeLogs/master_changelog.md` | Updated | This file — created in Session 12 (recreated after filesystem loss) |
| `05_ChangeLogs/version_manifest.yml` | Updated | Created in Session 12 (recreated after filesystem loss) |

### Infrastructure Events

```
VM 455 (vector.cleargeo.tech) — HTTP routing chain VERIFIED LIVE:
  fix: VM451 cvg-caddy proxy target vector → http://10.10.10.204:80 (was :8080 directly)
  fix: VM451 health_uri /status removed (Host: 10.10.10.204 → 308 → 503 cascade)
  fix: caddy/Caddyfile handle /status moved before reverse_proxy catch-all

VM 454 (raster.cleargeo.tech) — Same routing fixes applied on VM451 side

Verified production endpoints:
  https://vector.cleargeo.tech/status                             → "OK" 200 ✅
  https://vector.cleargeo.tech/geoserver/ows?service=WFS&...     → WFS_Capabilities 200 ✅
  https://raster.cleargeo.tech/status                            → "OK" 200 ✅
  https://raster.cleargeo.tech/geoserver/ows?service=WMS&...     → WMS_Capabilities 200 ✅
```

### Post-Deploy Checklist (v1.1.0)

- [x] DNS A record: `vector.cleargeo.tech → 131.148.52.225`
- [x] FortiGate VIP: `public:80+443 → 10.10.10.204:80+443`
- [x] HTTPS routing verified end-to-end via VM451
- [x] WFS GetCapabilities returning 200
- [ ] Run `scripts/geoserver-init.sh` to set admin password + `PROXY_BASE_URL` + create `cvg` workspace
- [ ] Register FEMA NFHL shapefiles from `/mnt/cgps` as Directory of Spatial Files datastore
- [ ] Configure PostGIS datastore (if DB available)
- [ ] Verify `PROXY_BASE_URL` appears correctly in WFS GetCapabilities `OnlineResource` URLs

---

## v1.0.0 — 2026-03-21 — Initial Release

**ChangeID:** `20260321-AZ-v1.0.0-v`
**Author:** Alex Zelenski, GISP
**Session:** 6

### Files Created

| File | Role | Notes |
|------|------|-------|
| `Dockerfile` | Container build | Multi-stage: extract+runtime; tini PID1; vector libs (geos/proj/spatialindex); container JVM; plugin installer |
| `docker-compose.yml` | Dev compose | Port 8080 exposed; dev image tag; localhost CSRF/PROXY |
| `docker-compose.prod.yml` | Prod compose | mem_limit:6g; cpus:3.0; ulimits; service_healthy; GWC volume; json logs |
| `caddy/Caddyfile` | Reverse proxy | Auto-HTTPS; CORS; security headers; max_body 50mb (WFS-T); handle_errors; JSON log |
| `deploy_production.sh` | VM provisioning | VM 455 cloud-init; Docker bootstrap; CIFS mounts; rsync; build+launch |
| `.dockerignore` | Build exclusions | war.zip; docs; scripts; Caddy config; Python artifacts |
| `.gitignore` | SCM exclusions | data_dir; logs; secrets; OS files; Python artifacts |
| `plugins/README.md` | Plugin guide | Install instructions for GeoServer extension ZIPs |
| `README.md` | Documentation | Quick start; endpoints; data stores; PostGIS config; infrastructure; security |
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
| OGC API Features | `https://vector.cleargeo.tech/geoserver/ogc/features/v1` |
| REST API | `https://vector.cleargeo.tech/geoserver/rest` |
| Admin UI | `https://vector.cleargeo.tech/geoserver/web` |

### Post-Deploy Checklist

- [x] DNS A record: `vector.cleargeo.tech → 131.148.52.225`
- [x] FortiGate VIP: `public:80+443 → 10.10.10.204:80+443`
- [ ] Change GeoServer admin password (default: `admin/geoserver`)
- [ ] Register NAS vector datasets (FEMA NFHL, HWM GeoPackage, AOI boundaries)
- [ ] Configure PostGIS datastore (if DB available)
- [ ] Verify `PROXY_BASE_URL` in GetCapabilities response URLs
'@

# ─── VECTOR version_manifest.yml ────────────────────────────────────────────
$vectorManifest = @'
# CVG GeoServer Vector — Version Manifest
# Standard: Z:/9999/Cline_Global_Rules/Change Log Requirements.md
# (c) Clearview Geographic LLC — All Rights Reserved

project: CVG GeoServer Vector
owner: Alex Zelenski, GISP
organization: Clearview Geographic, LLC
contact: azelenski@clearviewgeographic.com
website: https://www.clearviewgeographic.com
last_synced: "2026-03-22T06:46:00Z"
project_version: v1.1.0
change_id: 20260322-AZ-portal-v
last_deployment_note: "Session 12 — 2026-03-22 — Portal enhancements: basemap switcher, opacity slider, GetMap URL bar, WFS GetFeatureInfo JSON popup; deployed live to VM455"
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
  - version: "unreleased"
    date: "2026-03-22"
    change_id: "20260322-AZ-portal-v"
    summary: "Session 12 portal enhancements: basemap switcher (CartoDB/OSM/ESRI Satellite/OpenTopo), opacity slider, live GetMap URL bar, WFS GetFeatureInfo JSON attribute popup on click"
    breaking_changes: false
  - version: "1.1.0"
    date: "2026-03-22"
    change_id: "20260322-AZ-v1.1.0-v"
    summary: "HTTPS routing fixes verified; operational scripts formally tracked; _check_status cross-VM scripts added; Caddyfile hardened; both services live"
    breaking_changes: false
  - version: "1.0.0"
    date: "2026-03-21"
    change_id: "20260321-AZ-v1.0.0-v"
    summary: "Initial release — multi-stage Dockerfile, vectortiles/css/importer plugins, tini, container JVM, Caddy TLS, VM 455 infra"
    breaking_changes: false

versions:
  Dockerfile:
    version: v1.0.0
    last_modified: "2026-03-21"
    author: Alex Zelenski
    status: final_reviewed
    notes: "Multi-stage build (extract+runtime), tini PID1, vector libs (geos/proj/spatialindex), container-aware JVM, CSRF/PROXY vars; no GDAL overhead"
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
    notes: "v1.1.0: portal landing; /health probe; WPS LAN restriction; OGC API route; HTTP block for VM451; trusted_proxies; cache headers; CSP; handle_errors; /status ordering fixed"
  caddy/portal/index.html:
    version: v1.2.0-unreleased
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: deployed_live
    notes: "Session 12: basemap switcher (CartoDB/OSM/ESRI Satellite/OpenTopo), opacity slider, live GetMap URL bar, WFS GetFeatureInfo JSON attribute popup on click, scale bar added"
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
    notes: "Quick start, endpoints, PostGIS datastore config, infrastructure reference, security notes"
  CHANGELOG.md:
    version: v1.1.0
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: final_reviewed
    notes: "v1.1.0 section + [Unreleased] portal enhancement section (Session 12)"
  ROADMAP.md:
    version: v1.1.0
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: final_reviewed
    notes: "Session 12: v0.3.0 complete with portal; Next Steps; Current Live Status table; v0.4.0-v1.0.0 with curl examples; v0.7.0 WFS-T; Integration Matrix; Session History"
  scripts/control-flow.properties:
    version: v1.0.0
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: ready_to_deploy
    notes: "GeoServer control-flow plugin config: global=24, wfs.getfeature=12, wfs.transaction=4, wms.getmap=12, user=4, timeout=90s; install to data_dir to activate"
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
  05_ChangeLogs/version_manifest.yml:
    version: v1.2.0-unreleased
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: final_reviewed
    notes: "This file — recreated Session 12 (05_ChangeLogs dir was empty); portal/index.html and control-flow.properties entries added"
  05_ChangeLogs/master_changelog.md:
    version: v1.2.0-unreleased
    last_modified: "2026-03-22"
    author: Alex Zelenski
    status: final_reviewed
    notes: "Recreated Session 12 (05_ChangeLogs dir was empty); all 3 release entries added (v1.0.0, v1.1.0, [Unreleased] Session 12)"
'@

# ─── Write all four files ────────────────────────────────────────────────────
$rasterBase = "G:\07_APPLICATIONS_TOOLS\CVG_Geoserver_Raster"
$vectorBase = "G:\07_APPLICATIONS_TOOLS\CVG_Geoserver_Vector"

[System.IO.File]::WriteAllText("$rasterBase\05_ChangeLogs\master_changelog.md", $rasterMasterCL, $enc)
Write-Host "✅ Raster master_changelog.md written"

[System.IO.File]::WriteAllText("$rasterBase\05_ChangeLogs\version_manifest.yml", $rasterManifest, $enc)
Write-Host "✅ Raster version_manifest.yml written"

[System.IO.Directory]::CreateDirectory("$vectorBase\05_ChangeLogs") | Out-Null
[System.IO.File]::WriteAllText("$vectorBase\05_ChangeLogs\master_changelog.md", $vectorMasterCL, $enc)
Write-Host "✅ Vector master_changelog.md written"

[System.IO.File]::WriteAllText("$vectorBase\05_ChangeLogs\version_manifest.yml", $vectorManifest, $enc)
Write-Host "✅ Vector version_manifest.yml written"

Write-Host ""
Write-Host "All 4 changelog files updated successfully."
