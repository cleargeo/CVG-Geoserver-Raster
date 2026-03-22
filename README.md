# CVG GeoServer Raster

<!-- version: v1.0.0 | change_id: 20260321-AZ-v1.0.0 -->
[![Version](https://img.shields.io/badge/version-v1.0.0-blue)](CHANGELOG.md)
[![GeoServer](https://img.shields.io/badge/GeoServer-2.28.3-green)](https://geoserver.org)
[![Java](https://img.shields.io/badge/Java-17_JRE-orange)](https://adoptium.net)
[![License](https://img.shields.io/badge/license-Proprietary-red)](LICENSE)

**(c) Clearview Geographic LLC — All Rights Reserved | Est. 2018**
*Author: Alex Zelenski, GISP | azelenski@clearviewgeographic.com*

---

## Overview

CVG GeoServer Raster is a containerized [GeoServer 2.28.3](https://geoserver.org) instance tuned for high-throughput **raster tile and grid services**. It powers CVG's WMS/WCS/WMTS endpoints for GeoTIFF, Cloud Optimized GeoTIFF (COG), and ImageMosaic datasets — including flood depth grids, bathymetry, DEM surfaces, and storm surge outputs produced by the CVG wizard suite.

**Production URL:** `https://raster.cleargeo.tech`
**Host VM:** `cvg-geoserver-raster-01` (VMID 454) — `10.10.10.203`

---

## Services Provided

| Service | Endpoint | Description |
|---------|----------|-------------|
| WMS | `/geoserver/wms` | GetMap tiles, GetFeatureInfo |
| WCS | `/geoserver/wcs` | GetCoverage raster downloads |
| WMTS | `/geoserver/gwc/service/wmts` | Pre-rendered tile cache |
| TMS | `/geoserver/gwc/service/tms/1.0.0` | TMS tile protocol |
| REST API | `/geoserver/rest` | Layer management (admin only) |
| Web UI | `/geoserver/web` | Admin console |

---

## Quick Start — Local Development

### Prerequisites
- Docker Desktop (with WSL2 backend on Windows)
- `geoserver-2.28.3-bin.zip` present in this directory

### Run locally

```bash
# Build and start (GeoServer on http://localhost:8080)
docker compose up -d --build

# Watch startup logs (~90 seconds first boot)
docker logs -f geoserver-raster-dev

# Verify health
curl http://localhost:8080/geoserver/web/

# Default credentials (DEV ONLY — change before any real use)
# URL:      http://localhost:8080/geoserver/web/
# Username: admin
# Password: geoserver
```

### Stop

```bash
docker compose down
```

---

## Production Deployment

Production uses VM 454 on the CVG-QUEEN-11-PROXMOX cluster. The full deployment (VM creation → Docker → Caddy TLS) is automated:

```bash
# From DFORGE-100 Git Bash
cd "G:/07_APPLICATIONS_TOOLS/CVG_Geoserver_Raster"
bash deploy_production.sh
```

**What the deploy script does:**

| Step | Action |
|------|--------|
| 0 | Pre-flight: SSH key + file checks |
| 1 | Create VM 454 on Proxmox (Ubuntu 22.04, cloud-init) |
| 2 | Wait for SSH availability |
| 3 | Bootstrap: Docker CE, cifs-utils, directory layout |
| 4 | Mount TrueNAS CGPS + CGDP shares |
| 5 | rsync project files → VM |
| 6 | `docker compose -f docker-compose.prod.yml up -d --build` |
| 7 | Health check + summary |

### Required manual steps post-deploy

1. **DNS A record** — add to hive0 BIND9 or Cloudflare:
   ```
   raster   IN A   131.148.52.225
   ```

2. **FortiGate VIP** — forward public `131.148.52.225:80+443` → VM `10.10.10.203:80+443`

3. **Change admin password** — immediately after first successful boot:
   `https://raster.cleargeo.tech/geoserver/web/` → Security → Users/Groups → admin → Edit

4. **Configure CSRF whitelist** — if accessing from non-domain origins:
   Set `GEOSERVER_CSRF_WHITELIST=raster.cleargeo.tech` in `docker-compose.prod.yml`

---

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GEOSERVER_DATA_DIR` | `/opt/geoserver/data_dir` | GeoServer data directory (persisted volume) |
| `GEOSERVER_LOG_LOCATION` | `/var/log/geoserver/geoserver.log` | Log file path |
| `GEOSERVER_CSRF_WHITELIST` | *(unset)* | Comma-separated allowed origins for web UI |
| `GEOSERVER_LOG_PROFILE` | `DEFAULT_LOGGING.properties` | Log verbosity profile |
| `JAVA_OPTS` | See Dockerfile | JVM heap + GC settings |

### JVM Tuning (Raster-Optimized)

```
-Xms2g -Xmx6g          # 6 GB heap for ImageMosaic tile caching + large GeoTIFF reads
-XX:+UseG1GC            # Low-pause GC for tile serving
-XX:MaxGCPauseMillis=200
-Djava.awt.headless=true
```

Adjust `JAVA_OPTS` in `docker-compose.prod.yml` to match the VM's available RAM (VM 454 has 32 GB).

### Data Mounts

| Mount | Host Path | Access | Purpose |
|-------|-----------|--------|---------|
| `geoserver-data` | Docker volume | rw | GeoServer data directory (workspaces, stores, styles) |
| `/mnt/cgps` | `//10.10.10.100/cgps` | ro | TrueNAS CGPS — source raster datasets |
| `/mnt/cgdp` | `//10.10.10.100/cgdp` | ro | TrueNAS CGDP — processed flood grid outputs |

---

## Raster Data Stores

Typical data stores to configure after deployment:

### GeoTIFF Store
For individual flood depth grids / DEM surfaces:
- **Store type:** GeoTIFF
- **Connection URL:** `file:///mnt/cgdp/products/{project}/{layer}.tif`

### ImageMosaic Store
For multi-scene / multi-date mosaic datasets:
- **Store type:** ImageMosaic
- **Directory:** `file:///mnt/cgps/rasters/{mosaic-name}/`
- Requires `datastore.properties` + `indexer.properties` in mosaic directory

### Cloud Optimized GeoTIFF (HTTP COG)
For remotely-hosted COG files (S3, Azure Blob, NOAA Digital Coast):
- **Store type:** GeoTIFF (HTTP Data Store)
- **URL:** `https://.../{layer}.tif`

---

## Docker Image Details

| Property | Value |
|----------|-------|
| Base image | `eclipse-temurin:17-jre-jammy` |
| GeoServer | 2.28.3 (standalone Jetty) |
| User | `geoserver` (UID 1001, non-root) |
| Exposed port | `8080` |
| Health check | `GET /geoserver/web/` every 30s, 120s start period |
| Image size | ~1.2 GB (GDAL + JRE + GeoServer) |

---

## Infrastructure

| Component | Detail |
|-----------|--------|
| Proxmox host | CVG-QUEEN-11-PROXMOX (10.10.10.56) |
| VM ID | 454 — `cvg-geoserver-raster-01` |
| VM IP | 10.10.10.203 |
| VM RAM | 32 GB |
| VM vCPUs | 8 |
| VM Disk | 100 GB (PE-Enclosure1 ZFS pool) |
| Public IP | 131.148.52.225 (FortiGate NAT) |
| TLS | Caddy + Let's Encrypt auto-HTTPS |
| Network | TCP/80+443 → FortiGate VIP → VM 454 |

---

## Security Notes

- GeoServer runs as `geoserver` user (UID 1001) — not root
- REST API and admin console should be firewalled from public IP (use VPN/internal access only)
- Change default `admin/geoserver` password immediately
- Set `GEOSERVER_CSRF_WHITELIST` for web UI access control
- TrueNAS shares mounted read-only (`ro`) in container
- Caddy enforces HTTPS with HSTS (1-year max-age)

---

## Related Projects

| Project | Description |
|---------|-------------|
| `CVG_Geoserver_Vector` | Sister vector WFS/WMS service (VM 455, vector.cleargeo.tech) |
| `CVG_GeoServ_Processor` | Python pipeline: processes wizard outputs → publishes to GeoServer |
| `CVG_Storm Surge Wizard` | Generates surge depth grids consumed by this service |
| `CVG_SLR Wizard` | Generates SLR inundation grids consumed by this service |
| `CVG_Rainfall Wizard` | Generates rainfall depth grids consumed by this service |

---

*© Clearview Geographic LLC — Proprietary — All Rights Reserved*
