# CVG GeoServer Raster — Plugin Installation

**(c) Clearview Geographic LLC — All Rights Reserved**

Place GeoServer 2.28.3 extension ZIP files in this directory before running `docker compose build`.
The Dockerfile will automatically extract all `*.zip` files into `WEB-INF/lib` at build time.

---

## How It Works

```dockerfile
# From Dockerfile (Stage 1 — extract):
COPY plugins/ /build/plugins/

RUN for ZIP in /build/plugins/*.zip; do
        unzip -q -o "$ZIP" -d "$WEBINF"
    done
```

If a plugin ZIP is not present here, the Dockerfile attempts to download it from SourceForge
(requires internet access during build). Currently auto-downloaded: `css`, `importer`.

---

## Recommended Plugins for Raster Service

Download from: `https://sourceforge.net/projects/geoserver/files/GeoServer/2.28.3/extensions/`

| Plugin ZIP | Purpose | Priority |
|-----------|---------|----------|
| `geoserver-2.28.3-gdal-plugin.zip` | GDAL raster formats: ECW, MrSID, HDF4/5, NetCDF, COG via GDAL JNI | **HIGH** |
| `geoserver-2.28.3-pyramid-plugin.zip` | ImagePyramid — tiled multi-resolution raster mosaics | HIGH |
| `geoserver-2.28.3-css-plugin.zip` | CSS/YSLD cartographic styling (auto-downloaded as fallback) | MEDIUM |
| `geoserver-2.28.3-importer-plugin.zip` | Web-based bulk data importer UI (auto-downloaded as fallback) | MEDIUM |
| `geoserver-2.28.3-wps-plugin.zip` | OGC Web Processing Service (raster algebra, clipping) | MEDIUM |
| `geoserver-2.28.3-netcdf-plugin.zip` | NetCDF/CF raster coverage support | LOW |
| `geoserver-2.28.3-jp2k-plugin.zip` | JPEG 2000 raster format support | LOW |

---

## GDAL Plugin Notes

The `gdal-plugin` requires native GDAL JNI libraries. The Raster Dockerfile installs
`gdal-bin` + `libgdal-dev` on Ubuntu 22.04, and sets:

```
ENV GDAL_DATA=/usr/share/gdal
ENV LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:...
```

After installing the GDAL plugin ZIP here, GeoServer will use native GDAL for:
- Cloud Optimized GeoTIFF (COG) via VSICURL
- ECW / MrSID (requires separate licensed GDAL build)
- HDF4/5, NetCDF, GRIB

---

## Naming Convention

Plugin ZIPs must match the pattern:
```
geoserver-2.28.3-<name>-plugin.zip
```

Examples:
```
geoserver-2.28.3-gdal-plugin.zip
geoserver-2.28.3-pyramid-plugin.zip
geoserver-2.28.3-wps-plugin.zip
```

---

## Build & Verify

```bash
# Place ZIP(s) in this directory, then rebuild:
docker compose build --no-cache

# Verify plugin loaded in running container:
docker exec geoserver-raster-dev \
    ls /opt/geoserver/webapps/geoserver/WEB-INF/lib/ | grep gs-gdal

# Or check GeoServer web UI:
#   http://localhost:8080/geoserver/web/
#   → Server → About & Status → Modules
```

---

*This directory is excluded from Docker build context (via `.dockerignore`) except for `*.zip` files.*
*The `COPY plugins/ /build/plugins/` instruction in Stage 1 handles ZIP staging.*
