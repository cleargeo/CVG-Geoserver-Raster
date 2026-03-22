# CVG GeoServer Raster — Changelog

All notable changes to this project will be documented in this file.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) | CVG Standard: `Z:\9999\Cline_Global_Rules\Change Log Requirements.md`

---

## [Unreleased]

### Added (portal improvements — 2026-03-22)

#### caddy/portal/index.html — Major public-facing tool additions
- **Leaflet interactive map** (`raster-map`) — live WMS layer preview centred on US East/Gulf Coast; click map to query pixel value via WMS GetFeatureInfo; real-time lat/lon display; scale bar
- **Basemap switcher** — OpenStreetMap, OpenTopoMap, CartoDB Dark, ESRI Satellite (all free/public tile services)
- **Opacity slider** — adjustable WMS layer transparency in real time
- **Auto layer browser** — JavaScript fetches WMS GetCapabilities on load, parses `<Layer>` nodes, renders cards with layer name, title, abstract, and per-layer action buttons: **Preview** (loads on map), **GetMap URL** (copy to clipboard), **Download** (WCS GeoTIFF direct link)
- **Layer filter** — instant-search across layer name/title/abstract
- **WMS GetMap URL Builder** — form inputs for layer, format, width/height, bbox, CRS, style; "Use Map View" button syncs bbox from current map extent; generates full GetMap URL with one-click copy and browser-open
- **WCS Coverage Download Builder** — form inputs for coverage ID, format, spatial subset; generates WCS GetCoverage URL with curl snippet; "Use Map View" syncs bbox
- **Live GetMap URL display** — shows/updates the current-view GetMap URL below the map as the user pans/zooms
- **Copy-to-clipboard buttons** on all endpoint `<code>` blocks and `<pre>` code snippets (Clipboard API with fallback)
- **"Try in Browser"** links on all public OGC endpoint cards (WMS, WCS, OGC API)
- **Public access notice** badge in hero + green info banner advertising free no-account access
- **`meta name="description"`** and `robots: index,follow` for SEO discoverability
- **`<datalist>`** autocomplete on layer name inputs populated from live GetCapabilities

---

## [1.1.0] — 2026-03-22

### ChangeID: `20260322-AZ-v1.1.0`

**Caddyfile hardening, new operational scripts, and HTTPS routing fixes — both GeoServer services verified fully live end-to-end.**

### Added

#### scripts/ — New operational scripts
- **`scripts/geoserver-init.sh`** — First-run init via GeoServer REST API; sets admin password + proxy URL; removes demo workspaces; creates `cvg` workspace; idempotent sentinel prevents re-run
- **`scripts/health-check.sh`** — Comprehensive health check (`--local`, `--prod`, `--ip` modes); checks containers, portal, WMS + WCS + WMTS GetCapabilities, REST API LAN restriction, TLS cert expiry; exit code 1 on failure
- **`scripts/backup.sh`** — data_dir backup (`geoserver-raster-data` volume) via ephemeral alpine container; timestamped tarballs; `--dest`, `--keep` flags; integrity verify; backup manifest; cron example for VM 454
- **`scripts/reset-password.sh`** — Admin password reset via REST API; reads `.env`; auto-detects local vs. prod; verifies old + new password

#### caddy/Caddyfile — Significant hardening (replaces v1.0.0 draft)
- **Portal landing page** — `/` and `/portal/*` serve branded `/srv/portal` entry point
- **`/health` endpoint** — rewrites to `/geoserver/ows` internally; lightweight uptime probe target
- **WPS LAN restriction** — `/geoserver/wps*` returns 403 for public IPs; WPS is CPU-intensive, LAN-only
- **OGC API Features route** — `/geoserver/ogc/*` dedicated 60s/120s timeouts for JSON-LD responses
- **HTTP block** — explicit `http://raster.cleargeo.tech` block handles VM451 reverse-proxy forwarding (prevents redirect loop)
- **`trusted_proxies static 10.10.10.200`** — resolves real client IPs through VM451 Caddy layer
- **Cache-Control** — `@capabilities` (5 min public + stale-while-revalidate); `@gwc-tiles` (24h); `@ows-dynamic` + `@rest-api` (no-store)
- **`Content-Security-Policy`**, **`Permissions-Policy`**, **`X-XSS-Protection`** added to security header block
- **`handle_errors 502 503 504`** implemented — serves portal on upstream failures (was TODO in v1.0.0)
- **`handle /status`** moved before `reverse_proxy` catch-all (ordering bug — status fell through to GeoServer)
- **`request_body { max_size 200MB }`** correct block syntax (fixes v1.0.0 `limits` draft)

### Fixed

#### HTTPS Routing — Full End-to-End Production Verification (Sessions 10/11 — 2026-03-21)
- **VM451 proxy target corrected**: `cvg-caddy` was forwarding `raster.cleargeo.tech` directly to `cvg-geoserver-raster:8080`, bypassing `caddy-gsr` entirely — corrected to `http://10.10.10.203:80`
- **VM451 `health_uri` removed**: `health_uri /status` probes sent `Host: 10.10.10.203` causing `caddy-gsr` to return 308 → Caddy marked upstream unhealthy → cascading 503s; health probe removed
- **`handle /status` placement**: moved before bare `reverse_proxy` catch-all in both HTTP and HTTPS blocks; Caddy catch-all behaviour requires ordered routing

### Verified (Production — 2026-03-21)

| Endpoint | Result |
|---|---|
| `curl https://raster.cleargeo.tech/status` | `"OK"` HTTP 200 |
| `curl https://raster.cleargeo.tech/geoserver/ows?service=WMS&...GetCapabilities` | WMS_Capabilities XML HTTP 200 |
| `curl https://vector.cleargeo.tech/status` | `"OK"` HTTP 200 |
| `curl https://vector.cleargeo.tech/geoserver/ows?service=WFS&...GetCapabilities` | WFS_Capabilities XML HTTP 200 |

### Infrastructure (unchanged from v1.0.0)

| Item | Value |
|------|-------|
| VM | 454 — `cvg-geoserver-raster-01` @ 10.10.10.203 |
| Public URL | https://raster.cleargeo.tech |
| GeoServer | 2.28.3 (standalone Jetty) |
| Java | 17 JRE (`eclipse-temurin:17-jre-jammy`) |
| JVM heap | 6 GB (75% of 8 GB mem_limit) |

---

## [1.0.0] — 2026-03-21

### ChangeID: `20260321-AZ-v1.0.0`

**Initial release — production-ready GeoServer 2.28.3 raster service with full Docker infrastructure.**

### Added

#### Dockerfile
- Multi-stage build: `extract` (unzip + plugins) → `runtime` (clean JRE)
  - Stage 1 installs only `curl`, `unzip`, `wget`; no apt packages bleed into runtime image
- **Plugin installation system** — `plugins/` directory; ZIPs installed automatically at build time
  - Pre-supplied ZIPs copied from `plugins/*.zip` → `WEB-INF/lib`
  - Fallback: downloads `css` + `importer` plugins from SourceForge if not supplied
  - Raster plugin recommendations documented: gdal, pyramid, css, importer, wps
- **`tini` as PID 1** — `ENTRYPOINT ["/usr/bin/tini", "--"]` — ensures JVM receives `SIGTERM` cleanly on `docker stop`
- **Container-aware JVM tuning:**
  - `UseContainerSupport` — respects Docker `--memory` / `mem_limit`
  - `MaxRAMPercentage=75.0` — uses 75% of container memory as heap (6 GB at 8 GB limit)
  - `InitialRAMPercentage=25.0` — lean startup, grows on demand
  - `ExplicitGCInvokesConcurrent` — concurrent rather than stop-the-world System.gc()
  - `java.security.egd=file:/dev/./urandom` — avoid entropy starvation in containers
- **GDAL integration:** `GDAL_DATA=/usr/share/gdal`, `LD_LIBRARY_PATH` for GDAL plugin JNI
- **`PROXY_BASE_URL`** env var — ensures WMS/WCS GetCapabilities returns correct public URLs
- **`GEOSERVER_CSRF_WHITELIST=raster.cleargeo.tech`** — CSRF protection for Caddy-proxied admin UI
- **`GEOWEBCACHE_CACHE_DIR`** env var pointing to separate `/opt/geowebcache_data` volume
- WMS GetCapabilities healthcheck (`GET /geoserver/ows?service=wms&version=1.3.0&request=GetCapabilities`) — better signal than web UI page
- Non-root `geoserver` user (UID 1001, UID=shell `/bin/bash`)
- OCI labels: maintainer, title, description, vendor, version, licenses

#### docker-compose.prod.yml
- Hard resource limits: `mem_limit: 8g`, `memswap_limit: 8g`, `cpus: "6.0"`
- `ulimits.nofile: 65536` — GeoServer opens many FDs for raster tiles
- `stop_grace_period: 60s` — allows GeoServer to flush caches + finish requests
- `depends_on: condition: service_healthy` — Caddy starts only after GeoServer is healthy
- Separate `geoserver-gwc` named volume for GeoWebCache tile store
- `/var/log/geoserver` bind mount (host-side log retention)
- JSON logging driver with `max-size: 100m`, `max-file: 5` on GeoServer; smaller limits on Caddy/Watchtower
- `WATCHTOWER_LABEL_ENABLE=false` — Watchtower applies to all containers in stack
- Named networks: `cvg-gsr-web` + `cvg-gsr-internal` (isolated internal bridge)
- Caddy: `mem_limit: 256m`, `cpus: "1.0"`; Watchtower: `mem_limit: 64m`, `cpus: "0.25"`
- Comments documenting dual routing: dedicated VM454 VIP or via VM451 Caddy

#### docker-compose.yml (dev)
- Uses `cvg/geoserver-raster:dev` image tag (separate from prod `latest`)
- `PROXY_BASE_URL=http://localhost:8080/geoserver` for local GetCapabilities
- `GEOSERVER_CSRF_WHITELIST=localhost`
- Separate dev named volumes: `geoserver-raster-data-dev`, `geoserver-raster-gwc-dev`
- Commented `./data:/mnt/data:ro` mount for local raster test data

#### caddy/Caddyfile
- Auto-HTTPS via Let's Encrypt (HTTP-01 challenge)
- Reverse proxy to `geoserver-raster:8080` with 30s health check on `/geoserver/web/`
- `response_header_timeout: 120s`, `read_timeout: 300s`, `write_timeout: 300s` for large WCS downloads
- Security headers: `X-Frame-Options SAMEORIGIN`, `X-Content-Type-Options nosniff`, HSTS 1-year, Referrer-Policy
- CORS: OPTIONS preflight + `Access-Control-Allow-Origin *` for OGC client access
- Structured JSON access log, 14-day rotation, 100 MiB roll size
- gzip + zstd response compression
- `limits { max_body 200mb }` for large WCS GetCoverage requests
- *(TODO v1.0.0)* `handle_errors` block with 502/503/504 maintenance HTML — not yet added; tracked in ROADMAP v1.0.0

#### deploy_production.sh
- Creates VM 454 on Proxmox via PVE REST API + cloud-init (Ubuntu 22.04)
  - 32 GB RAM, 8 vCPU, 100 GB disk (PE-Enclosure1 ZFS pool)
  - SSH key injection via `qm set --sshkeys`
- VM bootstrap: Docker CE, cifs-utils, nfs-common, directory layout
- TrueNAS CGPS + CGDP CIFS mounts + persistent fstab entries
- rsync with `--exclude` for `.git`, `__pycache__`, `war.zip`
- Docker compose build + launch + 90s GeoServer initialization wait
- Health checks on GeoServer web UI + Caddy

#### Project files
- `.dockerignore` — excludes `war.zip`, docs, scripts, Caddy config, Python artifacts
- `.gitignore` — excludes `data_dir/`, logs, secrets, Python artifacts, OS files
- `plugins/` — plugin ZIP staging directory with `README.md` install instructions
- `README.md` — quick start, endpoints, data stores, infrastructure, security notes
- `CHANGELOG.md` — this file
- `ROADMAP.md` — versioned development roadmap v1.0.0 → v2.0.0
- `05_ChangeLogs/version_manifest.yml` — per-file version tracking
- `05_ChangeLogs/master_changelog.md` — master deployment log

### Infrastructure

| Item | Value |
|------|-------|
| VM | 454 — `cvg-geoserver-raster-01` @ 10.10.10.203 |
| Public URL | https://raster.cleargeo.tech |
| GeoServer | 2.28.3 (standalone Jetty) |
| Java | 17 JRE (`eclipse-temurin:17-jre-jammy`) |
| Caddy | 2-alpine |
| GDAL | Ubuntu 22.04 jammy packages |
| Docker Compose | v2 (plugin) |
| JVM heap | 6 GB (75% of 8 GB mem_limit) |

---

[Unreleased]: https://git.cvg.internal/clearview-geographic/cvg-geoserver-raster/compare/v1.1.0...HEAD
[1.1.0]: https://git.cvg.internal/clearview-geographic/cvg-geoserver-raster/compare/v1.0.0...v1.1.0
[1.0.0]: https://git.cvg.internal/clearview-geographic/cvg-geoserver-raster/releases/tag/v1.0.0
