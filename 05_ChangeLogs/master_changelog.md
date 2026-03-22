# CVG GeoServer Raster — Master Changelog

**Project:** CVG GeoServer Raster
**Standard:** `Z:\9999\Cline_Global_Rules\Change Log Requirements.md`
**(c) Clearview Geographic LLC — All Rights Reserved**

---

## Deployment Log

| Date | Version | ChangeID | Author | VM | Summary |
|------|---------|----------|--------|----|---------|
| 2026-03-22 | [Unreleased] | 20260322-AZ-backload | Alex Zelenski | All VMs | Session 13 — Backload Campaign priority established: BACKLOAD_PRIORITY.md created; ROADMAP.md updated with top-priority backload section; Z:\2018–Z:\2026 inventory + COG publish pipeline defined for raster + vector GeoServers |
| 2026-03-22 | [Unreleased] | 20260322-AZ-portal | Alex Zelenski | VM 454 | Session 12 — Portal enhancements live: basemap switcher, opacity slider, GetMap URL bar, WMS GetFeatureInfo on click |
| 2026-03-22 | v1.1.0 | 20260322-AZ-v1.1.0 | Alex Zelenski | VM 454 + VM 455 | Caddyfile hardening; 4 new operational scripts; HTTPS routing fixes; both GeoServer services verified live |
| 2026-03-21 | v1.0.0 | 20260321-AZ-v1.0.0 | Alex Zelenski | VM 454 (10.10.10.203) | Initial project scaffolding — multi-stage Dockerfile, plugin system, tini, container JVM, Caddy TLS, deploy script |

---

## [Unreleased] — Backload Campaign Priority — 2026-03-22 (Session 13)

**ChangeID:** `20260322-AZ-backload`
**Author:** Alex Zelenski, GISP
**Session:** 13

### Overview

Established the #1 operational priority for both CVG GeoServer platforms: systematically backload, categorize, and organize all previously collected project-specific geospatial data from the Z:\ project archive directories spanning 2018–2026. This initiative precedes all other GeoServer development work.

### Files Added

| File | Change | Notes |
|------|--------|-------|
| `BACKLOAD_PRIORITY.md` | New — top-priority plan | Full backload campaign plan: Z:\ priority table (P1–P5), 5-phase workflow (Inventory → Categorize → Process → Publish → Organize), layer naming convention, GeoServer workspace structure, master tracking register, scripts needed, immediate next actions, priority summary card |

### Files Modified

| File | Change | Notes |
|------|--------|-------|
| `ROADMAP.md` | Priority section inserted at top | New `## 🔴 TOP PRIORITY — Backload Campaign (Z:\ 2018–2026)` section added above v0.4.0; links to BACKLOAD_PRIORITY.md; priority table for Z:\2026→Z:\2018; 7-step immediate action list |
| `05_ChangeLogs/master_changelog.md` | Updated | This file — Session 13 backload entry added to deployment log |
| `05_ChangeLogs/version_manifest.yml` | Updated | BACKLOAD_PRIORITY.md + ROADMAP.md entries updated; new release entry added |

### Backload Campaign — Priority Table

| Priority | Directory | Load Order |
|----------|-----------|------------|
| 🔴 P1 — CRITICAL | `Z:\2026` · `Z:\2025` | Load NOW — most current data |
| 🟠 P2 — HIGH | `Z:\2024` · `Z:\2023` | Load NEXT — 2–3 years back |
| 🟡 P3 — MEDIUM | `Z:\2022` · `Z:\2021` | Load AFTER P2 complete |
| 🟢 P4 — STANDARD | `Z:\2020` · `Z:\2019` | Load in batch |
| 🔵 P5 — ARCHIVE | `Z:\2018` | Load last — founding year |

### Workflow Phases Defined

1. **Phase 1 — Inventory** — `find Z:/YEAR -type f ...` → generate raster + vector file lists per year
2. **Phase 2 — Categorization** — classify by type (`storm_surge`, `slr`, `rainfall`, `dem`, `reference`, `boundary`), CRS, publish priority
3. **Phase 3 — Processing** — `gdal_translate -of COG -co COMPRESS=DEFLATE` → output to `/mnt/cgdp/backload/{year}/{project}/`
4. **Phase 4 — Publishing** — GeoServer REST API: `POST coveragestores` / `POST datastores` per layer
5. **Phase 5 — Organization** — GeoServer layer groups per year + data type: `cvg:BL_{year}_{type}`

### Layer Naming Conventions Established

```
Raster:  cvg:{type}_{projectslug}_{year}_{scenario}
Vector:  cvg:{type}_{projectslug}_{year}
```

### Post-Deploy Checklist (Session 13)

- [x] BACKLOAD_PRIORITY.md created and saved to repo root
- [x] ROADMAP.md updated — backload section inserted as top priority
- [x] master_changelog.md updated — Session 13 entry added
- [ ] Run `scripts/geoserver-init.sh` — create `cvg` workspace (prerequisite for all publishing)
- [ ] Begin Phase 1 inventory: `Z:\2026` → `backload_inventory_2026_rasters.txt` + `backload_inventory_2026_vectors.txt`
- [ ] Create `scripts/backload_inventory.sh` — enumerate Z:\ year directory by file type
- [ ] Create `scripts/backload_cog_convert.sh` — batch COG conversion pipeline
- [ ] Create `scripts/backload_publish_raster.sh` — REST API layer registration (raster)
- [ ] Create `scripts/backload_publish_vector.sh` — REST API layer registration (vector)

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
