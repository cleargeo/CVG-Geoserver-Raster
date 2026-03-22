<!--
  © Clearview Geographic LLC -- All Rights Reserved | Est. 2018
  CVG GeoServer Raster — ROADMAP
  Author: Alex Zelenski, GISP | azelenski@clearviewgeographic.com
-->

# CVG GeoServer Raster — Development Roadmap

> Version: v1.1.0 | Author: Alex Zelenski, GISP
> Last updated: 2026-03-22 (Session 12 — Portal enhancements live; v0.3.0 complete)
> Production URL: **https://raster.cleargeo.tech** | VM 454 · 10.10.10.203 · 131.148.52.225

---

---

## 🔴 TOP PRIORITY — Backload Campaign (Z:\ 2018–2026)

> **This is the #1 active priority for both GeoServer platforms.**
> All previously collected project-specific data in the Z:\ archive directories must be inventoried, categorized, processed to COG, and published before any new wizard-generated data is onboarded.
> **Full plan → [`BACKLOAD_PRIORITY.md`](BACKLOAD_PRIORITY.md)**

| Priority | Directory | Status |
|----------|-----------|--------|
| 🔴 P1 — CRITICAL | `Z:\2026` · `Z:\2025` | 🔴 Inventory pending |
| 🟠 P2 — HIGH | `Z:\2024` · `Z:\2023` | 🔴 Inventory pending |
| 🟡 P3 — MEDIUM | `Z:\2022` · `Z:\2021` | 🔴 Inventory pending |
| 🟢 P4 — STANDARD | `Z:\2020` · `Z:\2019` | 🔴 Inventory pending |
| 🔵 P5 — ARCHIVE | `Z:\2018` | 🔴 Inventory pending |

**Immediate backload actions:**
1. **[ ] Run `scripts/backload_inventory.sh 2026`** → generate raster + vector file list for `Z:\2026`
2. **[ ] Classify data types** → `storm_surge` / `slr` / `rainfall` / `dem` / `reference` / `boundary`
3. **[ ] Copy source files to NAS** → `//10.10.10.100/cgps/backload/2026/{project}/`
4. **[ ] COG-convert all rasters** → `gdal_translate -of COG -co COMPRESS=DEFLATE`
5. **[ ] Run `geoserver-init.sh`** → creates `cvg` workspace (prerequisite for all publishing)
6. **[ ] Publish via REST API** → see `BACKLOAD_PRIORITY.md` Phase 4 for curl commands
7. **[ ] Repeat for 2025 → 2024 → … → 2018**

---

## ⚡ Next Steps — Immediate Actions (v0.4.0 Prerequisites)

> These must be done **directly on VM 454** before any raster data can be served via WMS/WCS.

1. **`bash scripts/geoserver-init.sh --prod`** — sets admin password, configures `PROXY_BASE_URL`, removes demo workspaces, creates `cvg` workspace
2. **Add `GEOSERVER_ADMIN_PASSWORD` to `.env`** on VM 454 → `/opt/cvg/CVG_Geoserver_Raster/.env`
3. **Verify `PROXY_BASE_URL`** in WMS GetCapabilities: `curl -s "https://raster.cleargeo.tech/geoserver/ows?service=WMS&version=1.3.0&request=GetCapabilities" | grep -i OnlineResource`
4. **Mount-verify CIFS**: `docker exec geoserver-raster gdalinfo /mnt/cgps/` — confirm CGPS/CGDP readable
5. **Configure first data store** (GeoTIFF or ImageMosaic): GeoServer UI → Stores → New → GeoTIFF / Image Mosaic

---

## Current Live Status

| Endpoint | URL | Status |
|----------|-----|--------|
| Portal | https://raster.cleargeo.tech | ✅ Live — branded landing page |
| WMS | https://raster.cleargeo.tech/geoserver/wms | ✅ Live — GetCapabilities verified |
| WCS | https://raster.cleargeo.tech/geoserver/wcs | ✅ Live |
| WMTS | https://raster.cleargeo.tech/geoserver/gwc/service/wmts | ✅ Live |
| OGC API | https://raster.cleargeo.tech/geoserver/ogc/features/v1 | ✅ Route active |
| Admin UI | https://raster.cleargeo.tech/geoserver/web | 🔒 LAN-only (10.10.10.0/24) |
| REST API | https://raster.cleargeo.tech/geoserver/rest | 🔒 LAN-only |
| Status | https://raster.cleargeo.tech/status | ✅ Returns "OK" |

> ⚠️ No CVG layers published yet — `cvg` workspace empty. See Next Steps above.

---

## Platform Summary

| Component | Detail |
|---|---|
| GeoServer | 2.28.3 (standalone Jetty, eclipse-temurin:17-jre-jammy) |
| Raster formats | COG (cloud-optimised GeoTIFF), ImageMosaic, GDAL multi-format |
| JVM heap | Container-aware: `MaxRAMPercentage=75.0` (approx 6 GB at 8 GB `mem_limit`) |
| GC | G1GC, `ExplicitGCInvokesConcurrent` |
| PID 1 | `tini` — clean SIGTERM delivery to JVM on `docker stop` |
| Reverse proxy | Caddy 2-alpine (TLS via Let's Encrypt HTTP-01, HTTP/3 UDP, admin UI LAN-only) |
| Updates | Watchtower (daily pull, `WATCHTOWER_POLL_INTERVAL=86400`) |
| NAS mounts | `/mnt/cgps` (CGPS share, read-only) · `/mnt/cgdp` (processed data, read-only) |
| Networks | `cvg-gsr-web` (bridge, public) · `cvg-gsr-internal` (bridge, internal) |
| DNS | `raster.cleargeo.tech -> 131.148.52.225` |

---

## CVG Platform Integration Map

```
                  +----------------------------+
                  |   TrueNAS NAS              |
                  |   /mnt/cgps  (raw rasters) |
                  |   /mnt/cgdp  (processed)   |
                  +----------+-----------------+
                             | :ro bind mounts
        +--------------------v------------------------------------------+
        |  VM 454  cvg-geoserver-raster-01  10.10.10.203               |
        |  +------------------+   +------------------------------+       |
        |  |  geoserver-raster|   |  caddy-gsr (TLS termination) |       |
        |  |  :8080 (Jetty)   |<--|  :80, :443, :443/udp (H3)   |       |
        |  +------------------+   +------------------------------+       |
        +------------------------------------------------------------------+
                             |
        WMS / WCS / WMTS raster endpoints consumed by:
         +-- SSW   storm surge depth grid tiles (WMS) + raw GeoTIFF (WCS)
         +-- SLR   SLR inundation rasters per year/scenario (WMS TIME + WCS)
         +-- Rainfall  runoff depth grid (WCS)
         +-- Public  portal layer browser, GetMap URL builder, GetFeatureInfo
```

---

## [DONE] v0.1.0 — Infrastructure Scaffolding (2026-03-21)

- [x] `Dockerfile`: multi-stage build (`extract` -> `runtime`) — clean JRE image
- [x] `plugins/` staging directory — auto-installs `css`, `importer`; fallback SourceForge downloads
- [x] `tini` as PID 1 — `ENTRYPOINT ["/usr/bin/tini", "--"]` — clean SIGTERM to JVM
- [x] Container-aware JVM: `UseContainerSupport`, `MaxRAMPercentage=75.0`, `InitialRAMPercentage=25.0`
- [x] `java.security.egd=file:/dev/./urandom` — fast entropy
- [x] GDAL integration: `GDAL_DATA=/usr/share/gdal`, `LD_LIBRARY_PATH` for GDAL plugin JNI
- [x] `PROXY_BASE_URL=https://raster.cleargeo.tech/geoserver` — correct GetCapabilities URLs
- [x] `GEOSERVER_CSRF_WHITELIST=raster.cleargeo.tech` — admin UI CSRF protection
- [x] `GEOWEBCACHE_CACHE_DIR=/opt/geowebcache_data` — separate named volume
- [x] WMS GetCapabilities healthcheck (`?service=wms&version=1.3.0&request=GetCapabilities`)
- [x] Non-root `geoserver` user (UID 1001)
- [x] `docker-compose.yml`: local dev stack (`:8080` exposed, dev image tag, localhost CSRF/PROXY)
- [x] `docker-compose.prod.yml`: `mem_limit: 8g`, `cpus: "6.0"`, `ulimits.nofile: 65536`, `stop_grace_period: 60s`
- [x] `docker-compose.prod.yml`: `depends_on: service_healthy`; separate `geoserver-gwc` volume; JSON logs; named networks
- [x] `deploy_production.sh`: `--redeploy`, `--no-cache`, `--target` flags
- [x] `.dockerignore`, `plugins/README.md`, `README.md`, `CHANGELOG.md`, `.gitignore`
- [x] `05_ChangeLogs/version_manifest.yml` + `05_ChangeLogs/master_changelog.md`
- [x] `scripts/geoserver-init.sh`, `scripts/health-check.sh`, `scripts/backup.sh`, `scripts/reset-password.sh`

## [DONE] v0.2.0 — Caddyfile Complete (2026-03-21)

- [x] `caddy/Caddyfile` for `raster.cleargeo.tech -> geoserver-raster:8080`
- [x] Admin UI (`/geoserver/web/*`) restricted to LAN `10.10.10.0/24` — 403 for public requests
- [x] `flush_interval -1` — WCS/WMS tile responses streamed immediately (no buffering)
- [x] `response_header_timeout 120s` + `read/write_timeout 300s` for large WCS GeoTIFF downloads
- [x] `request_body { max_size 200MB }` — large WCS GetCoverage POST requests
- [x] Security headers: HSTS 1-year, X-Frame-Options SAMEORIGIN, `-X-Powered-By`
- [x] CORS: OPTIONS preflight + `Access-Control-Allow-Origin *` + `Access-Control-Max-Age: 86400`
- [x] WMS GetCapabilities health check endpoint for upstream monitoring
- [x] Structured JSON access log `/var/log/caddy/geoserver-raster-access.log` (100 MiB roll, 14 days)
- [x] gzip + zstd compression (WMS tiles compress well; WCS GeoTIFF streams raw)

## [DONE] v0.3.0 — First Live Service on VM 454 + Portal (2026-03-21/22)

- [x] Run `bash deploy_production.sh` from DFORGE-100 to provision VM 454
- [x] DNS A record: `raster IN A 131.148.52.225` in CT104 BIND9
- [x] FortiGate VIP: `131.148.52.225:80+443 -> VM451:80+443 -> 10.10.10.203:80+443`
- [x] `https://raster.cleargeo.tech/status` returns 200 — verified live (Sessions 10/11)
- [x] `https://raster.cleargeo.tech/geoserver/ows?service=WMS` returns WMS_Capabilities — verified
- [x] HTTPS routing via VM451 fully operational (3-fix chain: proxy target, status ordering, health_uri)
- [x] `_check_status.bat` + `_check_status.sh` added for cross-VM health monitoring
- [x] Caddy hardened: portal landing, `/health` probe, WPS LAN restriction, cache-control headers, CSP, `handle_errors`
- [x] `caddy/portal/index.html` live — branded service portal; auto WMS layer browser; WCS/WMTS endpoint cards; QGIS/Python/curl code examples
- [x] **Portal enhancements (Session 12):** basemap switcher (CartoDB/OSM/ESRI Satellite/OpenTopo), opacity slider, live GetMap URL bar, WMS GetFeatureInfo (pixel value) on click

---

## [TODO] v0.4.0 — First Data: Admin Init + NAS / GeoTIFF Datastores

> **Prerequisites** (complete before other v0.4.0 tasks):
> - [ ] Run `scripts/geoserver-init.sh --prod` on VM 454 (SSH: `ubuntu@10.10.10.203`)
> - [ ] Add `GEOSERVER_ADMIN_PASSWORD` to `/opt/cvg/CVG_Geoserver_Raster/.env`
> - [ ] Verify `PROXY_BASE_URL` in WMS GetCapabilities `OnlineResource` URLs

**NAS Raster Datasets:**
- [ ] Mount verify: `docker exec geoserver-raster gdalinfo /mnt/cgps/` — confirm CGPS/CGDP readable + GDAL drivers available
- [ ] Create GeoServer workspace `cvg` (done by init.sh) + verify: `curl -u admin:$PW https://raster.cleargeo.tech/geoserver/rest/workspaces`
- [ ] Register first COG GeoTIFF as WMS+WCS layer (e.g. `/mnt/cgdp/ssw/test_depth.tif` → `cvg:test_depth`)
- [ ] Apply SLD colormap: depth gradient (0–10 ft, configurable) — test via WMS GetMap
- [ ] Register NOAA reference raster (storm surge baseline) from `/mnt/cgps/noaa/`
- [ ] Test `GetMap`: `curl "https://raster.cleargeo.tech/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=cvg:test_depth&FORMAT=image/png&CRS=EPSG:4326&WIDTH=512&HEIGHT=512&BBOX=28,-92,32,-88&STYLES=" -o /tmp/test_tile.png`
- [ ] Test `GetCoverage`: `curl "https://raster.cleargeo.tech/geoserver/wcs?SERVICE=WCS&VERSION=2.0.1&REQUEST=GetCoverage&COVERAGEID=cvg__test_depth&FORMAT=image/tiff" -o /tmp/test_cov.tif`

**ImageMosaic Setup (for multi-tile coverage):**
- [ ] Create mosaic index for large area rasters (gdaltindex or GeoServer auto-index)
- [ ] Register ImageMosaic datastore; test GetMap at different zoom levels
- [ ] Configure GeoWebCache gridset for EPSG:4326 + EPSG:3857

**Layer Quality:**
- [ ] Set `maxRenderingTime: 30000` and `maxRasterizationMB: 256` global GeoServer settings
- [ ] Configure default rendering style per layer (SLD with appropriate colormap + no-data transparency)
- [ ] Verify `GetFeatureInfo` returns pixel value for each raster layer

---

## [TODO] v0.5.0 — SSW Raster Integration (Storm Surge Depth Grid)

**SSW Processing Pipeline:**
- [ ] Add COG export step: depth grid → `gdal_translate -of COG -co COMPRESS=DEFLATE` → `/mnt/cgdp/ssw/{project}/{scenario}/depth.tif`
- [ ] Layer naming convention: `cvg:ssw_{project}_{scenario}` (e.g. `cvg:ssw_hca2024_cat3`)
- [ ] GeoServer auto-registration: `SSW web_api.py GET /api/layers/raster` returns WMS GetCapabilities URL
- [ ] Auto-publish via REST API after each SSW run: `POST /geoserver/rest/workspaces/cvg/coveragestores`
- [ ] SLD colormap parametric: accepts `min_depth`, `max_depth` → dynamic colour ramp

**SSW CVG Dash Integration:**
- [ ] WMS tile overlay in Dash map (Plotly Express mapbox or Leaflet.js)
- [ ] WCS download button for raw GeoTIFF in SSW results panel
- [ ] `GetFeatureInfo` integration: click on map → query pixel depth at point
- [ ] Layer switcher: compare multiple scenario depth grids side by side

---

## [TODO] v0.6.0 — SLR + Rainfall Raster Integration

- [ ] SLR: per-scenario per-year inundation GeoTIFF → `cvg:slr_{project}_{year}_{scenario}`
- [ ] WMS TIME dimension for animated SLR progression (year slider in Dash)
- [ ] Rainfall: runoff depth grid → `cvg:rain_{project}_{event}`
- [ ] Automated WMS layer deregistration after project archival (REST API DELETE)
- [ ] Cross-service query: WMS GetMap + Vector WFS GetFeature at same bbox → combined Dash output

---

## [TODO] v0.7.0 — GeoWebCache Optimisation

- [ ] Pre-seed WMTS tile pyramids for commonly-used layers (z5–z15): `curl -u admin:$PW -X POST "https://raster.cleargeo.tech/geoserver/gwc/rest/seed/cvg:test_depth.json"`
- [ ] Disk quota management: GWC → Disk Quota → 50 GB limit
- [ ] GutterSize=32 for seamless tile blending at zoom transitions (SLD scale denominators)
- [ ] BlobStore: separate named volume already configured; verify path in GWC settings
- [ ] TileLayer expiry: 24h for static reference data; no-cache for dynamic run output

---

## [TODO] v1.0.0 — Production Hardening

- [ ] REST API layer auto-registration script runs on each SSW/SLR/Rainfall deploy (`CVG_GeoServ_Processor`)
- [ ] Watchtower Discord/email webhook on image update
- [ ] Log shipping: `geoserver.log` + Caddy access log → Loki on CT104
- [ ] Rate limiting in Caddy: `rate_limit {remote_ip} 100r/m` for WMS GetMap (prevent tile scraping)
- [ ] `maxRenderingTime: 30s` + `maxRasterizationMB: 256` GeoServer global limits
- [ ] OGC security: REST API locked to `cvg-gsr-internal`; WMS/WCS/WMTS public read-only
- [ ] Automated `scripts/health-check.sh --prod` via Proxmox scheduled task (cron on VM 454 + alert if exit≠0)
- [ ] GeoServer data_dir backup cron: `scripts/backup.sh --dest /mnt/cgdp/backups/geoserver-raster --keep 14`
- [ ] `handle_errors` maintenance page in Caddyfile already implemented ✅

---

## Integration Matrix (Cross-Wizard)

| Wizard | Data Type | GeoServer Service | Layer Pattern | Status |
|--------|-----------|-------------------|---------------|--------|
| Storm Surge | Depth grid GeoTIFF | WMS + WCS | `cvg:ssw_{project}_{scenario}` | TODO v0.5.0 |
| SLR | Inundation GeoTIFF per year | WMS (TIME dim) + WCS | `cvg:slr_{project}_{year}_{scenario}` | TODO v0.6.0 |
| Rainfall | Runoff depth grid | WCS | `cvg:rain_{project}_{event}` | TODO v0.6.0 |
| All | COG tile cache | WMTS (GeoWebCache) | `cvg:gwc_{layer}` | TODO v0.7.0 |

---

## Infrastructure Register

| Resource | Value |
|---|---|
| VM | 454 (`cvg-geoserver-raster-01`) |
| Internal IP | 10.10.10.203 |
| Public IP | 131.148.52.225 |
| Hostname | raster.cleargeo.tech |
| Container | `geoserver-raster` |
| Proxy container | `caddy-gsr` |
| GeoServer version | 2.28.3 |
| Java runtime | eclipse-temurin:17-jre-jammy |
| JVM heap | 6 GB (75% of 8 GB `mem_limit`) |
| NAS mounts | /mnt/cgps (ro), /mnt/cgdp (ro) |
| Watchtower | daily poll (`watchtower-gsr`) |
| SSH | `ssh -i ~/.ssh/cvg_neuron_proxmox ubuntu@10.10.10.203` |

---

## Session History

| Session | Date | Focus | Outcome |
|---|---|---|---|
| Session 12 | 2026-03-22 | Portal enhancements | Basemap switcher (CartoDB/OSM/ESRI Satellite/OpenTopo), opacity slider, live GetMap URL bar, WMS GetFeatureInfo on click; deployed live to VM454 |
| Session 11 | 2026-03-22 | HTTPS routing verification + status scripts | Routing verified live; _check_status scripts added; 4 operational scripts registered; Caddyfile hardened; v0.3.0 complete |
| Session 10/11 | 2026-03-21 | HTTPS routing fix | VM451 proxy target corrected; health_uri removed; handle /status ordering fixed; raster+vector services live |
| Session 7 | 2026-03-21 | Docker hardening + Caddyfile + deploy script | Multi-stage Dockerfile; plugin system; tini; container JVM; Caddyfile (LAN restriction, flush, limits); --redeploy/--target flags |

---

*CVG GeoServer Raster v1.1.0 — Updated 2026-03-22 (Session 12)*
*© Clearview Geographic, LLC — Proprietary — CVG-ADF*
