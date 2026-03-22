<!--
  © Clearview Geographic LLC -- All Rights Reserved | Est. 2018
  CVG Platform — Master Priority Roadmap
  Author: Alex Zelenski, GISP | azelenski@clearviewgeographic.com
-->

# CVG Platform — Master Priority Roadmap

> **Version:** v1.0.0 | **Author:** Alex Zelenski, GISP
> **Issued:** 2026-03-22 | **ChangeID:** `20260322-AZ-platform-roadmap`
> **Scope:** Full CVG platform — GeoServer Raster · GeoServer Vector · Wizard Suite · CVG Dash · CVG_GeoServ_Processor · Client Deliverables · Infrastructure

---

## 🧭 How to Read This Roadmap

| Badge | Meaning |
|-------|---------|
| 🔴 **P0 — BLOCKING** | Must complete before anything else can function |
| 🟠 **P1 — CRITICAL** | Directly enables revenue, client deliverables, or core product |
| 🟡 **P2 — HIGH** | Major user experience or workflow improvement |
| 🟢 **P3 — STANDARD** | Important but not blocking; builds polish + reliability |
| 🔵 **P4 — ENHANCEMENT** | Advanced features; long-term platform excellence |

**Effort Scale:** `XS` < 1 day · `S` 1–3 days · `M` 1–2 weeks · `L` 2–4 weeks · `XL` 1+ month

**Status:** `🔴 Not Started` · `🟡 In Progress` · `✅ Done` · `⏸ Blocked`

---

## 🔴 TIER 0 — Foundation (Everything Blocks On This)

> These items must be completed before any downstream features can function. Every other item in this roadmap depends on at least one item here.

---

### T0-01 · Backload Campaign — Z:\ Project Archive (2018–2026)
**Priority:** 🔴 P0 — BLOCKING | **Effort:** XL | **Status:** 🟡 In Progress (plan established)
**Domain:** Data | **Impacts:** All users — engineers, planners, clients, management

**Why critical:** CVG has 8+ years of project-specific geospatial data collected across 9 Z:\ year directories that is completely inaccessible over standard OGC protocols. Until this data is in GeoServer, CVG cannot serve any historical deliverables, compare scenarios across years, provide client map portals, or run cross-project analysis. This is the single most impactful near-term action.

**Deliverable plan:** See [`BACKLOAD_PRIORITY.md`](BACKLOAD_PRIORITY.md)

**Sub-tasks:**
- [ ] Phase 1 — Inventory: Z:\2026 → Z:\2018 (enumerate all raster + vector files per year)
- [ ] Phase 2 — Categorize: classify by type (`storm_surge`, `slr`, `rainfall`, `dem`, `boundary`, etc.)
- [ ] Phase 3 — Process: COG conversion (rasters via `gdal_translate`) + GPKG conversion (vectors via `ogr2ogr`)
- [ ] Phase 4 — Publish: REST API registration in raster.cleargeo.tech + vector.cleargeo.tech
- [ ] Phase 5 — Organize: GeoServer layer groups per year + data type (`cvg:BL_{year}_{type}`)
- [ ] Scripts: `backload_inventory.sh`, `backload_cog_convert.sh`, `backload_gpkg_convert.sh`, `backload_publish_raster.sh`, `backload_publish_vector.sh`

**User impact:** Engineers get instant access to all historical project layers in QGIS/ArcGIS. Clients get map portals showing their complete project history. Management gets platform credibility.

---

### T0-02 · GeoServer Admin Init — Both Instances
**Priority:** 🔴 P0 — BLOCKING | **Effort:** XS | **Status:** 🔴 Not Started
**Domain:** Infrastructure | **Impacts:** All GeoServer users

**Why critical:** Neither GeoServer instance has been initialized. Admin password is default (`admin/geoserver`), `cvg` workspace does not exist, `PROXY_BASE_URL` is unverified. No layers can be published until init is complete.

**Actions:**
```bash
# VM 454 (Raster):
ssh ubuntu@10.10.10.203 "cd /opt/cvg/CVG_Geoserver_Raster && bash scripts/geoserver-init.sh --prod"

# VM 455 (Vector):
ssh ubuntu@10.10.10.204 "cd /opt/cvg/CVG_Geoserver_Vector && bash scripts/geoserver-init.sh --prod"
```

- [ ] Set `GEOSERVER_ADMIN_PASSWORD` in `.env` on both VMs
- [ ] Run `geoserver-init.sh` on VM 454 — create `cvg` workspace, set `PROXY_BASE_URL`
- [ ] Run `geoserver-init.sh` on VM 455 — create `cvg` workspace, set `PROXY_BASE_URL`
- [ ] Verify: `curl -u admin:$PW https://raster.cleargeo.tech/geoserver/rest/workspaces`

---

### T0-03 · NAS CIFS Mount Verification — Both GeoServer Containers
**Priority:** 🔴 P0 — BLOCKING | **Effort:** XS | **Status:** 🔴 Not Started
**Domain:** Infrastructure | **Impacts:** All data publishing

**Why critical:** GeoServer reads data directly from NAS paths (`/mnt/cgps`, `/mnt/cgdp`). If mounts are stale or not readable by the container, no data stores can be registered.

```bash
docker exec geoserver-raster gdalinfo /mnt/cgps/    # Raster: verify GDAL reads NAS
docker exec geoserver-vector ogrinfo /mnt/cgdp/ --formats  # Vector: verify OGR reads NAS
```

- [ ] Verify CIFS mounts on VM 454 container: `/mnt/cgps` + `/mnt/cgdp`
- [ ] Verify CIFS mounts on VM 455 container: `/mnt/cgps` + `/mnt/cgdp`
- [ ] Verify `backload/` subdirectory is writable on NAS for COG output
- [ ] Confirm fstab entries survive VM reboot

---

## 🟠 TIER 1 — Core Data Services (Revenue & Deliverable Enabling)

> These items bring CVG's data online and make GeoServer genuinely useful for engineers and clients. Each has immediate, direct impact on billable project deliverables.

---

### T1-01 · First Raster Layers Published — Storm Surge Depth Grids
**Priority:** 🟠 P1 — CRITICAL | **Effort:** S | **Status:** ⏸ Blocked (T0-01, T0-02, T0-03)
**Domain:** Raster GeoServer | **Impacts:** SSW engineers, project managers, clients

**Why critical:** Storm surge depth grids are CVG's flagship raster product. Getting a single grid into WMS turns the empty portal into a functioning deliverable platform immediately.

- [ ] Register first COG depth grid as `cvg:ssw_{project}_{scenario}` coverage store
- [ ] Apply SLD depth colormap (depth gradient 0–10 ft, blue→red scale, transparent no-data)
- [ ] Verify WMS GetMap: `curl "https://raster.cleargeo.tech/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=cvg:ssw_hca2024_cat3&FORMAT=image/png&..."  -o /tmp/map.png`
- [ ] Verify WCS GetCoverage: `curl "https://raster.cleargeo.tech/geoserver/wcs?...&COVERAGEID=cvg__ssw_hca2024_cat3&FORMAT=image/tiff" -o /tmp/depth.tif`
- [ ] Verify WMS GetFeatureInfo returns pixel depth value at clicked point

**User impact:** Engineers can overlay depth grids in QGIS directly from the live service. Clients get a real-time map portal the day the model run finishes.

---

### T1-02 · First Vector Layers Published — Flood Extents + AOI Boundaries
**Priority:** 🟠 P1 — CRITICAL | **Effort:** S | **Status:** ⏸ Blocked (T0-01, T0-02, T0-03)
**Domain:** Vector GeoServer | **Impacts:** SSW engineers, project managers, clients

- [ ] Register first surge extent GPKG as `cvg:surge_extent_{project}_{scenario}` datastore
- [ ] Register first AOI boundary GPKG as `cvg:aoi_{project}`
- [ ] Apply SLD styles: flood extent (translucent blue fill, dark blue outline) + AOI boundary (dashed orange)
- [ ] Verify WFS GetFeature: `curl "https://vector.cleargeo.tech/geoserver/wfs?...&typeNames=cvg:surge_extent_hca2024_cat3&outputFormat=application/json"`
- [ ] Verify OGC API Features: `https://vector.cleargeo.tech/geoserver/ogc/features/v1/collections/cvg:surge_extent_hca2024_cat3/items`

---

### T1-03 · FEMA Reference Layers — NFHL Flood Zones + Base Flood Elevation
**Priority:** 🟠 P1 — CRITICAL | **Effort:** M | **Status:** 🔴 Not Started
**Domain:** Vector GeoServer | **Impacts:** All SSW/SLR projects, regulatory compliance

**Why critical:** Every CVG project references FEMA NFHL flood zones and DFIRM panels. Publishing these as permanent WFS/WMS layers eliminates per-project data handling and enables real-time comparison of project results against regulatory baselines.

- [ ] Source FEMA NFHL data from `/mnt/cgps/fema/` or download via FEMA MSC API for project counties
- [ ] Register NFHL Special Flood Hazard Area polygons: `cvg:fema_sfha_{county}`
- [ ] Register DFIRM Base Flood Elevation lines: `cvg:fema_bfe_{county}`
- [ ] Register DFIRM panel boundaries: `cvg:fema_panels_{state}`
- [ ] SLD styles: SFHA zones (AE=blue, AO=green, X=yellow, etc. — standard FEMA color scheme)
- [ ] Layer groups: `cvg:fema_nfhl_{state}` — all NFHL layers for a state as single WMS reference

**User impact:** Engineers overlay FEMA zones against surge depth grids in one click. Clients see regulatory context alongside model results in the map portal.

---

### T1-04 · DEM / Lidar Elevation Surfaces — Published as WMS+WCS
**Priority:** 🟠 P1 — CRITICAL | **Effort:** M | **Status:** 🔴 Not Started
**Domain:** Raster GeoServer | **Impacts:** All SSW/SLR/Rainfall engineers

**Why critical:** DEMs and lidar surfaces are the terrain input for all CVG wizards. Publishing them as WCS services enables direct server-to-server data access from wizard processing pipelines — eliminating manual file transfers.

- [ ] Register project DEMs from `/mnt/cgps/dem/` + `/mnt/cgdp/dem/`
- [ ] COG conversion with overviews: `gdal_translate -of COG -co COMPRESS=DEFLATE -co OVERVIEW_RESAMPLING=BILINEAR`
- [ ] Layer naming: `cvg:dem_{projectslug}_{year}_{source}` (e.g. `cvg:dem_nola_2024_usgs3dep`)
- [ ] SLD hillshade colormap (gray elevation gradient + hillshade blend)
- [ ] WCS endpoint verified for wizard pipeline consumption: `GetCoverage → float32 TIFF`
- [ ] NOAA Digital Coast lidar tiles: COG + mosaic index for multi-tile coverage

---

### T1-05 · ImageMosaic Setup — Multi-Tile + Multi-Scene Raster Datasets
**Priority:** 🟠 P1 — CRITICAL | **Effort:** M | **Status:** 🔴 Not Started
**Domain:** Raster GeoServer | **Impacts:** SSW/SLR engineers, large-area projects

**Why critical:** Many CVG project areas span multiple raster tiles. Without ImageMosaic, each tile must be registered as a separate layer — unmanageable at scale.

- [ ] `gdaltindex` mosaic index creation for each multi-tile dataset
- [ ] GeoServer auto-index via ImageMosaic datastore (`datastore.properties` + `indexer.properties`)
- [ ] Configure GeoWebCache gridset: EPSG:4326 (100k–1:1k) + EPSG:3857 (web map tiles z5–z18)
- [ ] Test seamless tile blending: `GutterSize=32` in GetMap renderer settings
- [ ] Register NOAA storm surge advisory rasters as TIME-enabled mosaic (historical storm archive)

---

## 🟡 TIER 2 — Wizard Integration (Core CVG Product Automation)

> These items automate the bridge between CVG's wizard processing outputs and the GeoServer publishing layer. They eliminate manual steps from every project workflow and are the primary platform differentiator.

---

### T2-01 · CVG_GeoServ_Processor — Automated Layer Publishing Pipeline
**Priority:** 🟡 P2 — HIGH | **Effort:** L | **Status:** 🔴 Not Started
**Domain:** Pipeline / Integration | **Impacts:** All CVG engineers, every project

**Why critical:** Currently, publishing a layer to GeoServer requires manual REST API calls. `CVG_GeoServ_Processor` is the Python pipeline that watches for wizard output files and auto-publishes them. This eliminates the per-project publishing step entirely.

- [ ] Python package: `cvg_geoserv_processor/`
  - `publi sh.py` — main entry point; reads `layer_config.yaml`; calls GeoServer REST API
  - `cog.py` — wraps `gdal_translate -of COG` with standard CVG settings
  - `gpkg.py` — wraps `ogr2ogr -f GPKG -t_srs EPSG:4326`
  - `rest_client.py` — GeoServer REST API client (coverage store, datastore, featuretype, coverages)
  - `sld.py` — SLD template rendering (depth gradient, flood extent, elevation, boundary)
  - `layer_registry.py` — tracks published layers + metadata in SQLite (`layer_registry.db`)
- [ ] Trigger: called by SSW/SLR/Rainfall wizard after processing completes → `publish_layer(project_id, layer_type, file_path)`
- [ ] Config: `layer_config.yaml` per wizard type — naming convention, SLD template, workspace, enabled services

---

### T2-02 · SSW Auto-Publish — Depth Grid + Flood Extent After Each Run
**Priority:** 🟡 P2 — HIGH | **Effort:** S | **Status:** 🔴 Not Started
**Domain:** SSW Integration | **Impacts:** SSW engineers, clients, project managers

**Why critical:** After each storm surge model run, the depth grid and flood extent should be instantly available via WMS/WFS without any manual steps from the engineer.

**Raster (depth grid):**
- [ ] SSW `web_api.py` calls `cvg_geoserv_processor.publish(type="storm_surge_depth", file=depth.tif, project=project_id, scenario=scenario)`
- [ ] COG conversion → `/mnt/cgdp/ssw/{project}/{scenario}/depth_cog.tif`
- [ ] REST API: create `coverageStore` + publish `coverage` → `cvg:ssw_{project}_{scenario}`
- [ ] SLD: blue→red depth gradient (parametric: `min_depth`, `max_depth` from wizard config)
- [ ] Layer visible in portal immediately after publish

**Vector (flood extent):**
- [ ] SSW exports flood-extent polygon → `extent.gpkg`
- [ ] `ogr2ogr` GPKG → `/mnt/cgdp/ssw/{project}/{scenario}/extent.gpkg`
- [ ] REST API: create `dataStore` + publish `featureType` → `cvg:surge_extent_{project}_{scenario}`
- [ ] Cross-service layer group: `cvg:ssw_{project}_{scenario}` = depth raster + extent vector

---

### T2-03 · SLR Auto-Publish — Per-Year Per-Scenario Inundation + WMS TIME Dimension
**Priority:** 🟡 P2 — HIGH | **Effort:** M | **Status:** 🔴 Not Started
**Domain:** SLR Integration | **Impacts:** SLR engineers, planners, clients

**Why critical:** SLR projects produce multiple inundation grids per scenario per year (2030/2050/2070/2100 × 1ft/2ft/4ft/6ft). TIME-enabled WMS enables animated year-slider in the Dash interface — a compelling client deliverable.

- [ ] SLR wizard exports per-year inundation GeoTIFF → `cvg:slr_{project}_{year}_{scenario}`
- [ ] ImageMosaic with TIME attribute = year (GeoServer time-series mosaic)
- [ ] WMS GetMap with `TIME=2050` parameter → returns 2050 inundation layer
- [ ] Dash year-slider: `TIME` parameter changes dynamically; map animates inundation progression
- [ ] SLR vector boundary: shoreline / inundation extent polygon per scenario → WFS + WMS

---

### T2-04 · Rainfall Auto-Publish — Runoff Depth Grid + Drainage Basins
**Priority:** 🟡 P2 — HIGH | **Effort:** S | **Status:** 🔴 Not Started
**Domain:** Rainfall Integration | **Impacts:** Rainfall/drainage engineers

- [ ] Rainfall wizard exports runoff depth grid → `cvg:rain_{project}_{event}` (e.g. `100yr_24hr`)
- [ ] SLD: runoff depth gradient (green→yellow→red, 0–12 inches)
- [ ] Drainage basin polygons (SSURGO HSG boundaries, catchment areas) → WFS `cvg:basin_{project}`
- [ ] WCS download of raw runoff grid available from portal

---

### T2-05 · CVG Dash — WMS Tile Overlay Integration
**Priority:** 🟡 P2 — HIGH | **Effort:** M | **Status:** 🔴 Not Started
**Domain:** CVG Dash / Frontend | **Impacts:** All wizard users, clients

**Why critical:** All CVG wizards use a Dash-based results interface. Integrating WMS/WFS directly into Dash maps gives clients an in-app live layer view — making the wizard output immediately visual without leaving the application.

- [ ] Dash map: Leaflet.js or Plotly `dash-leaflet` component
- [ ] WMS tile layer: `L.tileLayer.wms("https://raster.cleargeo.tech/geoserver/wms", {layers: "cvg:ssw_{project}_{scenario}", format: "image/png", transparent: true, opacity: 0.7})`
- [ ] WFS vector overlay: GeoJSON from `GetFeature?outputFormat=application/json` → `L.geoJSON()` in Dash map
- [ ] Click → `GetFeatureInfo` popup: pixel depth value (raster) + feature attributes (vector)
- [ ] Scenario switcher: each storm category / SLR year / rainfall event = separate WMS layer
- [ ] Download button: WCS `GetCoverage` → raw GeoTIFF download for client

---

### T2-06 · Layer Registry API — Central Layer Index for All Wizards
**Priority:** 🟡 P2 — HIGH | **Effort:** M | **Status:** 🔴 Not Started
**Domain:** Integration / API | **Impacts:** All wizard products, platform consistency

**Why critical:** As layers multiply across wizards, years, and projects, a central registry prevents duplicates, enables cross-project comparison, and gives wizards a unified `GET /api/layers` endpoint to discover what's published.

- [ ] `GET /api/platform/layers` — returns all published layers with metadata (project, year, type, WMS URL, WCS URL, bbox, CRS)
- [ ] `GET /api/platform/layers?project={id}` — filter by project
- [ ] `GET /api/platform/layers?type=storm_surge` — filter by data type
- [ ] SQLite or PostgreSQL backing store (`layer_registry.db`)
- [ ] `CVG_GeoServ_Processor` writes to registry on publish
- [ ] All wizard dashboards query registry for "load existing layer" UX

---

## 🟢 TIER 3 — Client-Facing Deliverable Features

> These items directly improve the experience for CVG's paying clients. They turn raw data access into polished, professional deliverables.

---

### T3-01 · Client Map Portal — Project-Specific Layer Browser
**Priority:** 🟢 P3 — STANDARD | **Effort:** M | **Status:** 🔴 Not Started
**Domain:** Portal / Client UX | **Impacts:** Clients (primary), engineers

**Why critical:** Clients should be able to navigate to `https://raster.cleargeo.tech/portal/{project_id}/` and see all layers for their specific project — without seeing unrelated project data.

- [ ] URL pattern: `/portal/project/{project_slug}/` — Caddy routes to project-filtered portal
- [ ] Portal JS: auto-fetches WMS GetCapabilities filtered to `cvg:{type}_{projectslug}_*`
- [ ] Layer cards: Preview / Download / WMS GetMap URL per layer
- [ ] Basemap switcher + opacity slider (already done for main portal)
- [ ] Side-by-side compare: split-screen two layer dates or scenarios
- [ ] Password protection option for pre-delivery client access (Caddy `basic_auth`)

---

### T3-02 · Report-Quality Map Generation — WMS GetMap for Static Report Figures
**Priority:** 🟢 P3 — STANDARD | **Effort:** S | **Status:** 🔴 Not Started
**Domain:** Deliverable Tools | **Impacts:** Engineers, clients, project reports

**Why critical:** CVG engineers currently produce report maps manually in ArcGIS/QGIS. A WMS-based map generator produces consistent, high-resolution map figures at defined scales in seconds.

- [ ] Map figure generator: Python script → `requests.get(WMS GetMap URL, params={width:2400, height:1800, dpi:300, bbox:project_bbox})`
- [ ] Layout: map + scale bar + north arrow + legend + CVG logo watermark → PDF/PNG
- [ ] Triggered from wizard dashboard: "Generate Report Map" button → calls script → returns map image
- [ ] Predefined layouts: `flood_extent`, `depth_grid`, `slr_comparison`, `rainfall_runoff`
- [ ] Output: `{project_id}_{scenario}_{date}_map.pdf` delivered to `/mnt/cgdp/{project}/maps/`

---

### T3-03 · QGIS/ArcGIS Connection Guide — Client + Engineer Onboarding
**Priority:** 🟢 P3 — STANDARD | **Effort:** XS | **Status:** 🔴 Not Started
**Domain:** Documentation / Client UX | **Impacts:** All GIS users

- [ ] QGIS: Layer → Add Layer → WMS/WMTS → URL: `https://raster.cleargeo.tech/geoserver/wms`
- [ ] QGIS: Layer → Add Layer → WFS → URL: `https://vector.cleargeo.tech/geoserver/wfs`
- [ ] ArcGIS Pro: Map → Add Data → Data From Path → WMS service
- [ ] Connection guide: PDF + web page hosted at portal (`/docs/connect`)
- [ ] curl + Python requests examples for programmatic layer download (WCS)
- [ ] Published as `caddy/portal/docs/connect.html`

---

### T3-04 · WCS GeoTIFF Download — Direct Raster Download for Clients
**Priority:** 🟢 P3 — STANDARD | **Effort:** XS | **Status:** 🟡 In Progress (portal UI exists, no layers yet)
**Domain:** Raster GeoServer | **Impacts:** Clients, engineers

- [ ] Portal WCS Download Builder already implemented (SessionS 12) — verify once layers exist
- [ ] Default format: `image/tiff` (GeoTIFF COG)
- [ ] Spatial subsetting: use current map view bbox or manual entry
- [ ] CRS selection: EPSG:4326, EPSG:32615/16/17 (UTM), EPSG:3857
- [ ] Size warning: display estimated download size before triggering download
- [ ] curl snippet: auto-generates copy-pasteable `curl` command for server-side download

---

### T3-05 · Cross-Scenario Comparison — Side-by-Side WMS Layer View
**Priority:** 🟢 P3 — STANDARD | **Effort:** M | **Status:** 🔴 Not Started
**Domain:** Portal / Client UX | **Impacts:** Engineers (primarily), clients

**Why critical:** Comparing Cat3 vs. Cat5 surge depth, or 2050 vs. 2100 SLR, side-by-side is a core deliverable pattern in CVG's work. A swipe/split-screen tool makes this self-service for clients.

- [ ] Split-screen map: left panel + right panel, each with independent WMS layer + opacity
- [ ] Swipe comparison: draggable vertical divider between two maps (Leaflet `leaflet-side-by-side` plugin)
- [ ] Scenario selectors: dropdowns populated from WMS GetCapabilities filtered by project
- [ ] Difference layer: if two depth grids selected → compute and display difference raster (WPS or client-side)
- [ ] Share URL: encode both active layers + bbox in URL for client sharing

---

### T3-06 · Automated Project Archival — Layer Deregistration on Project Close
**Priority:** 🟢 P3 — STANDARD | **Effort:** S | **Status:** 🔴 Not Started
**Domain:** Data Lifecycle | **Impacts:** Platform operations

- [ ] `CVG_GeoServ_Processor deregister_project(project_id)` — REST API DELETE all layers + stores for project
- [ ] Move source data: `/mnt/cgdp/{project}/` → `/mnt/cgdp/archive/{year}/{project}/`
- [ ] Retain GeoServer metadata record in layer_registry.db with `status=archived`
- [ ] Archive portal: `https://raster.cleargeo.tech/portal/archive/` — browse archived projects, re-activate on request

---

## 🟢 TIER 3 — Platform Performance & Reliability

---

### T3-07 · GeoWebCache Tile Seeding — Pre-render Tiles for Common Layers
**Priority:** 🟢 P3 — STANDARD | **Effort:** S | **Status:** 🔴 Not Started
**Domain:** Raster GeoServer Performance | **Impacts:** Portal users, map load speed

- [ ] Pre-seed FEMA NFHL layers (static reference data): zoom levels 5–15
- [ ] Pre-seed backloaded project layers (historical data, rarely changes): z5–z14
- [ ] Disk quota: GWC → Disk Quota → 50 GB limit per GeoServer instance
- [ ] Tile expiry: 24h static (background layers); no-cache for wizard run outputs (dynamic)
- [ ] `curl -u admin:$PW -X POST "https://raster.cleargeo.tech/geoserver/gwc/rest/seed/cvg:{layer}.json" -d '{"seedRequest":{"name":"cvg:{layer}","bounds":...,"gridSetId":"EPSG:4326","type":"seed","threadCount":2,"zoomStart":5,"zoomStop":15}}'`

---

### T3-08 · Automated Backup System — GeoServer data_dir + NAS Data
**Priority:** 🟢 P3 — STANDARD | **Effort:** XS | **Status:** 🔴 Not Started
**Domain:** Operations | **Impacts:** Platform reliability, disaster recovery

- [ ] `scripts/backup.sh` cron on VM 454: daily at 02:00 → `/mnt/cgdp/backups/geoserver-raster/`
- [ ] `scripts/backup.sh` cron on VM 455: daily at 02:30 → `/mnt/cgdp/backups/geoserver-vector/`
- [ ] Retention: `--keep 14` (14 days of daily backups)
- [ ] Alert on failure: `curl -X POST $WEBHOOK` if backup exits non-zero
- [ ] TrueNAS snapshot: daily ZFS snapshot of `cgdp` dataset (separate from GeoServer backup)

---

### T3-09 · Health Monitoring + Alerting — Automated Failure Notification
**Priority:** 🟢 P3 — STANDARD | **Effort:** S | **Status:** 🔴 Not Started
**Domain:** Operations | **Impacts:** Platform uptime, engineer confidence

- [ ] Cron on VM 454: `*/5 * * * * bash scripts/health-check.sh --prod || curl -X POST $DISCORD_WEBHOOK -d '{"content":"🔴 raster.cleargeo.tech health check FAILED"}'`
- [ ] Cron on VM 455: same pattern for vector service
- [ ] Proxmox alert: VM 454/455 down → Proxmox notification email
- [ ] Uptime monitoring: add `https://raster.cleargeo.tech/status` to external uptime monitor (UptimeRobot / Grafana Cloud free tier)
- [ ] TLS cert expiry check: `health-check.sh` already implemented — alert 30 days before expiry

---

### T3-10 · Rate Limiting + DDoS Protection — Caddy Rate Limiting Rules
**Priority:** 🟢 P3 — STANDARD | **Effort:** XS | **Status:** 🔴 Not Started
**Domain:** Security | **Impacts:** Platform stability, preventing tile scraping

- [ ] Caddy `rate_limit` plugin: 100 req/min per IP for WMS GetMap (raster)
- [ ] Caddy `rate_limit` plugin: 200 req/min per IP for WFS GetFeature (vector)
- [ ] WCS GetCoverage: 10 req/min per IP (large downloads, CPU-intensive)
- [ ] Admin UI: already LAN-only — no additional rate limiting needed
- [ ] Block large bbox WMS requests: `maxRasterizationMB=256` in GeoServer global settings

---

## 🔵 TIER 4 — Advanced Platform Features

> Long-term enhancements that add significant value but require foundational layers to be complete first.

---

### T4-01 · PostGIS Integration — Spatial Database Backend for Vector GeoServer
**Priority:** 🔵 P4 — ENHANCEMENT | **Effort:** L | **Status:** 🔴 Not Started
**Domain:** Vector GeoServer | **Impacts:** All vector data users

**Why valuable:** PostGIS enables complex spatial queries, CQL filter optimization, WFS-T transactions with row-level security, and much larger feature sets than GeoPackage file-per-layer approach.

- [ ] Deploy PostgreSQL 16 + PostGIS 3.4 on CT/VM on Proxmox (or dedicated DB VM)
- [ ] Import backloaded GPKG layers: `ogr2ogr -f PostgreSQL PG:"dbname=cvg_spatial" layer.gpkg`
- [ ] GeoServer PostGIS datastore: `jdbc:postgresql://10.10.10.XXX:5432/cvg_spatial` with `geoserver_ro` account
- [ ] CQL filter optimization: PostGIS spatial index → WFS `CQL_FILTER=project_id='hca2024'` uses index
- [ ] Connection pool: `min=5, max=20` connections

---

### T4-02 · WFS-T Transactional Editing — Field Data Entry from QGIS
**Priority:** 🔵 P4 — ENHANCEMENT | **Effort:** M | **Status:** 🔴 Not Started
**Domain:** Vector GeoServer | **Impacts:** CVG field engineers, QA staff

**Why valuable:** CVG field staff collecting High Water Marks (HWM) or observational data can update GeoServer feature attributes directly from QGIS in the field without any server-side scripting.

- [ ] Enable WFS-T on `cvg-gsv-internal` network only (Caddy blocks `Transaction` from public)
- [ ] PostGIS required (T4-01 prerequisite)
- [ ] Row-level security: users can only edit features where `assigned_user = current_user` (PostgreSQL RLS + GeoServer `role` filter)
- [ ] Audit log: PostgreSQL trigger → `audit_log` table records all WFS-T writes
- [ ] QGIS WFS-T guide: connect to `https://vector.cleargeo.tech/geoserver/wfs` with credentials

---

### T4-03 · OGC API Features Compliance — Modern REST JSON API for Layers
**Priority:** 🔵 P4 — ENHANCEMENT | **Effort:** S | **Status:** 🟡 In Progress (route active, no layers)
**Domain:** Both GeoServers | **Impacts:** Web developers, modern API consumers

- [ ] OGC API Features endpoint verified: `https://vector.cleargeo.tech/geoserver/ogc/features/v1/collections`
- [ ] GeoJSON output per collection: `GET /collections/{layer}/items?limit=100&bbox=...`
- [ ] CQL2 filter support: `GET /collections/{layer}/items?filter=depth_ft>5`
- [ ] OpenAPI spec served at `/geoserver/ogc/features/v1/api` → swagger UI for developer exploration
- [ ] Document OGC API alongside WFS in client connection guide

---

### T4-04 · Log Shipping — GeoServer + Caddy Logs to Loki + Grafana
**Priority:** 🔵 P4 — ENHANCEMENT | **Effort:** M | **Status:** 🔴 Not Started
**Domain:** Operations | **Impacts:** Platform observability

- [ ] Loki on CT104 (Proxmox container): `docker run grafana/loki:latest`
- [ ] Grafana on CT104: `docker run grafana/grafana:latest` — Loki datasource
- [ ] Promtail on VM 454: ships `geoserver-raster-access.log` (Caddy JSON) + `geoserver.log` → Loki
- [ ] Promtail on VM 455: same for vector service
- [ ] Grafana dashboards: WMS request rate, response time, error rate, top layers, top IPs
- [ ] Alert: response time > 10s sustained → Discord notification

---

### T4-05 · Watchtower Webhook — Discord/Email on Image Update
**Priority:** 🔵 P4 — ENHANCEMENT | **Effort:** XS | **Status:** 🔴 Not Started
**Domain:** Operations | **Impacts:** Operations awareness

- [ ] `WATCHTOWER_NOTIFICATION_URL=discord://{webhook_id}/{webhook_token}` in `docker-compose.prod.yml`
- [ ] Test: force image update → verify Discord message received
- [ ] Include in both `CVG_Geoserver_Raster` and `CVG_Geoserver_Vector` compose files

---

### T4-06 · Multi-Tenant Project Workspaces — Per-Client GeoServer Namespace
**Priority:** 🔵 P4 — ENHANCEMENT | **Effort:** L | **Status:** 🔴 Not Started
**Domain:** Both GeoServers / Architecture | **Impacts:** Client data isolation, enterprise contracts

**Why valuable:** Enterprise clients or government agencies may require their project data to be isolated in a dedicated GeoServer workspace with separate access credentials — enabling per-client billing and data governance.

- [ ] Create per-client workspace: `{client_code}` (e.g. `hca`, `port_fourchon`, `nola`)
- [ ] Layer naming: `{client_code}:ssw_{scenario}` instead of `cvg:ssw_{project}_{scenario}`
- [ ] GeoServer security: `ROLE_{CLIENT}` group → read access to `{client_code}:*` layers only
- [ ] Caddy routing: `https://raster.cleargeo.tech/geoserver/{client_code}/wms` → workspace-scoped WMS
- [ ] Portal: `https://raster.cleargeo.tech/portal/{client_code}/` — per-client layer browser with branding

---

## 📊 Priority Summary Matrix

| ID | Feature | Priority | Effort | Status | Impact |
|----|---------|----------|--------|--------|--------|
| T0-01 | Z:\ Backload Campaign | 🔴 P0 | XL | 🟡 In Progress | ★★★★★ |
| T0-02 | GeoServer Admin Init | 🔴 P0 | XS | 🔴 Not Started | ★★★★★ |
| T0-03 | NAS CIFS Mount Verify | 🔴 P0 | XS | 🔴 Not Started | ★★★★★ |
| T1-01 | First Raster Layers (SSW) | 🟠 P1 | S | ⏸ Blocked | ★★★★★ |
| T1-02 | First Vector Layers (Extent/AOI) | 🟠 P1 | S | ⏸ Blocked | ★★★★★ |
| T1-03 | FEMA NFHL Reference Layers | 🟠 P1 | M | 🔴 Not Started | ★★★★☆ |
| T1-04 | DEM/Lidar Surfaces | 🟠 P1 | M | 🔴 Not Started | ★★★★☆ |
| T1-05 | ImageMosaic Multi-Tile | 🟠 P1 | M | 🔴 Not Started | ★★★☆☆ |
| T2-01 | CVG_GeoServ_Processor Pipeline | 🟡 P2 | L | 🔴 Not Started | ★★★★★ |
| T2-02 | SSW Auto-Publish | 🟡 P2 | S | 🔴 Not Started | ★★★★★ |
| T2-03 | SLR Auto-Publish + TIME | 🟡 P2 | M | 🔴 Not Started | ★★★★☆ |
| T2-04 | Rainfall Auto-Publish | 🟡 P2 | S | 🔴 Not Started | ★★★☆☆ |
| T2-05 | CVG Dash WMS Integration | 🟡 P2 | M | 🔴 Not Started | ★★★★★ |
| T2-06 | Layer Registry API | 🟡 P2 | M | 🔴 Not Started | ★★★★☆ |
| T3-01 | Client Project Portal | 🟢 P3 | M | 🔴 Not Started | ★★★★☆ |
| T3-02 | Report Map Generator | 🟢 P3 | S | 🔴 Not Started | ★★★★☆ |
| T3-03 | QGIS/ArcGIS Connect Guide | 🟢 P3 | XS | 🔴 Not Started | ★★★☆☆ |
| T3-04 | WCS GeoTIFF Download | 🟢 P3 | XS | 🟡 In Progress | ★★★★☆ |
| T3-05 | Cross-Scenario Comparison | 🟢 P3 | M | 🔴 Not Started | ★★★★☆ |
| T3-06 | Project Archival + Deregister | 🟢 P3 | S | 🔴 Not Started | ★★★☆☆ |
| T3-07 | GeoWebCache Tile Seeding | 🟢 P3 | S | 🔴 Not Started | ★★★☆☆ |
| T3-08 | Automated Backup Cron | 🟢 P3 | XS | 🔴 Not Started | ★★★★☆ |
| T3-09 | Health Monitoring + Alerts | 🟢 P3 | S | 🔴 Not Started | ★★★★☆ |
| T3-10 | Rate Limiting + DDoS | 🟢 P3 | XS | 🔴 Not Started | ★★★☆☆ |
| T4-01 | PostGIS Integration | 🔵 P4 | L | 🔴 Not Started | ★★★★☆ |
| T4-02 | WFS-T Transactional Editing | 🔵 P4 | M | 🔴 Not Started | ★★★☆☆ |
| T4-03 | OGC API Features Compliance | 🔵 P4 | S | 🟡 In Progress | ★★★☆☆ |
| T4-04 | Log Shipping → Loki/Grafana | 🔵 P4 | M | 🔴 Not Started | ★★★☆☆ |
| T4-05 | Watchtower Webhook | 🔵 P4 | XS | 🔴 Not Started | ★★☆☆☆ |
| T4-06 | Multi-Tenant Workspaces | 🔵 P4 | L | 🔴 Not Started | ★★★★☆ |

---

## 🗓️ Recommended Execution Sequence

```
WEEK 1–2  (Foundation)
  → T0-02: GeoServer admin init — BOTH instances (2 hours)
  → T0-03: NAS CIFS mount verify (1 hour)
  → T0-01: Begin Z:\2026 inventory + COG/GPKG conversion (ongoing)

WEEK 2–3  (First Data Online)
  → T1-01: Publish first SSW depth grid raster (COG → WMS/WCS)
  → T1-02: Publish first surge extent + AOI boundary vector (GPKG → WFS)
  → T1-03: FEMA NFHL shapefiles → WMS reference layer(s)
  → T3-03: QGIS connection guide — publish to portal (½ day)

WEEK 3–4  (Backload Pipeline + Operations)
  → T0-01: Continue backload (Z:\2025, 2024, 2023 — COG/GPKG batch)
  → T3-08: Backup cron — both VMs (30 min)
  → T3-09: Health check cron + Discord alert (1 hour)
  → T1-04: DEM/Lidar surfaces from NAS → WCS

MONTH 2   (Automation Pipeline)
  → T2-01: CVG_GeoServ_Processor Python package (L effort — 2 weeks)
  → T2-02: SSW auto-publish hook (ties into T2-01)
  → T2-05: CVG Dash WMS tile overlay (parallel with T2-01)

MONTH 2–3 (Client Deliverables)
  → T3-01: Client project portal (M effort)
  → T3-02: Report map generator
  → T3-05: Cross-scenario compare view
  → T2-03: SLR TIME dimension + Dash year slider
  → T2-06: Layer Registry API

MONTH 3+  (Advanced / Enterprise)
  → T4-01: PostGIS deployment + migration
  → T4-02: WFS-T + row-level security
  → T3-07: GeoWebCache tile seeding
  → T4-04: Loki/Grafana log shipping
  → T4-06: Multi-tenant workspaces (enterprise contracts)
```

---

## 🏢 User Base Impact Summary

| User Group | Immediate Win (T0–T1) | Medium-term Win (T2–T3) | Long-term Win (T4) |
|------------|----------------------|------------------------|-------------------|
| **CVG Engineers** | Historical layers in QGIS over WMS instantly | Wizard auto-publish — no manual steps | WFS-T field editing, PostGIS queries |
| **CVG Management** | Platform credibility — 8 years of data online | Client portals — self-service deliverables | Multi-tenant enterprise contracts |
| **Project Clients** | WCS GeoTIFF download, QGIS guide | Project portal, scenario compare, report maps | Per-client workspace isolation |
| **Regulatory / Planning** | FEMA NFHL reference layers online | SLR TIME animation for planning scenarios | OGC API for GIS system integration |
| **Public / General** | Public read-only WMS portalwith open data | Layer browser, GetFeatureInfo on click | Open API documentation |

---

## 📁 Related Documents

| Document | Purpose |
|----------|---------|
| [`BACKLOAD_PRIORITY.md`](BACKLOAD_PRIORITY.md) | Full backload campaign plan (T0-01) |
| [`ROADMAP.md`](ROADMAP.md) | GeoServer Raster version roadmap |
| [`CVG_Geoserver_Vector/ROADMAP.md`](../CVG_Geoserver_Vector/ROADMAP.md) | GeoServer Vector version roadmap |
| [`CVG_Geoserver_Vector/BACKLOAD_PRIORITY.md`](../CVG_Geoserver_Vector/BACKLOAD_PRIORITY.md) | Vector backload plan |
| [`scripts/geoserver-init.sh`](scripts/geoserver-init.sh) | T0-02 prerequisite script |
| [`scripts/health-check.sh`](scripts/health-check.sh) | T3-09 health monitoring |
| [`scripts/backup.sh`](scripts/backup.sh) | T3-08 backup automation |

---

*CVG Platform Master Priority Roadmap v1.0.0 — Issued 2026-03-22 (Session 13)*
*© Clearview Geographic, LLC — Proprietary — CVG-ADF*
