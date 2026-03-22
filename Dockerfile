# =============================================================================
# (c) Clearview Geographic LLC -- All Rights Reserved | Est. 2018
# CVG GeoServer Raster — Docker Image
# Author: Alex Zelenski, GISP | azelenski@clearviewgeographic.com
# GeoServer 2.28.3 — Raster-optimized (ImageMosaic, GeoTIFF, COG, WMS/WCS)
# =============================================================================
# Build stages:
#   stage 1 (extract)  — unzips GeoServer binary + installs plugins
#   stage 2 (runtime)  — clean JRE image, copies extracted GeoServer
# This keeps the final image free of apt build-deps and zip artifacts.
# =============================================================================

# ── Stage 1: Extract GeoServer + install plugins ──────────────────────────────
FROM eclipse-temurin:17-jre-jammy AS extract

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        unzip \
        wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy and extract the GeoServer standalone binary (embedded Jetty).
# NOTE: geoserver-2.28.3-bin.zip extracts FLAT (no top-level subdirectory).
#       Extract directly into the target directory using -d to avoid mv failure.
COPY geoserver-2.28.3-bin.zip ./
RUN mkdir -p geoserver \
    && unzip -q geoserver-2.28.3-bin.zip -d geoserver \
    && rm geoserver-2.28.3-bin.zip

# ── Plugin installation ───────────────────────────────────────────────────────
# Place any pre-downloaded plugin ZIPs in plugins/ directory before building.
# Required naming: geoserver-2.28.3-<name>-plugin.zip
# Recommended for raster service:
#   geoserver-2.28.3-gdal-plugin.zip        — GDAL raster formats (ECW, HDF, etc.)
#   geoserver-2.28.3-pyramid-plugin.zip     — ImagePyramid tiled raster mosaics
#   geoserver-2.28.3-css-plugin.zip         — CSS/YSLD cartographic styling
#   geoserver-2.28.3-importer-plugin.zip    — Web-based bulk data importer
#   geoserver-2.28.3-wps-plugin.zip         — OGC Web Processing Service
#
# If plugins/ directory has ZIPs they are installed here.
# Otherwise, key plugins are downloaded from SourceForge.
# =============================================================================
COPY plugins/ /build/plugins/

RUN set -e; \
    WEBINF="/build/geoserver/webapps/geoserver/WEB-INF/lib"; \
    \
    # Install any pre-supplied plugin ZIPs first
    for ZIP in /build/plugins/*.zip; do \
        [ -f "$ZIP" ] || continue; \
        echo "[plugins] Installing $(basename $ZIP)..."; \
        unzip -q -o "$ZIP" -d "$WEBINF"; \
    done; \
    \
    # Download fallback plugins if not already supplied
    # Raster plugin set:
    #   css            — CSS/YSLD cartographic styling
    #   importer       — Web-based bulk data importer UI
    #   control-flow   — Request rate limiting and concurrency control
    #   wps            — OGC Web Processing Service (raster analysis: crop, resample, reproject)
    #   ysld           — YSLD compact styling language (alternative to SLD)
    #   vector-tiles   — MapboxVectorTile / GeoJSON vector tile output from WMS
    GS_VER="2.28.3"; \
    SF_BASE="https://sourceforge.net/projects/geoserver/files/GeoServer/${GS_VER}/extensions"; \
    for PLUGIN in css importer control-flow wps ysld vector-tiles; do \
        # Check by jar prefix (plugin JARs contain the plugin name in their filename)
        PLUGIN_SAFE=$(echo "${PLUGIN}" | tr '-' '_'); \
        if ! ls ${WEBINF}/gs-${PLUGIN}-*.jar ${WEBINF}/gs-${PLUGIN_SAFE}-*.jar 2>/dev/null | grep -q .; then \
            echo "[plugins] Downloading ${PLUGIN} plugin..."; \
            ZIP="geoserver-${GS_VER}-${PLUGIN}-plugin.zip"; \
            wget -q --retry-connrefused --tries=3 --timeout=90 \
                 -O "/tmp/${ZIP}" \
                 "${SF_BASE}/${ZIP}/download" 2>/dev/null \
            && unzip -q -o "/tmp/${ZIP}" -d "$WEBINF" \
            && rm -f "/tmp/${ZIP}" \
            || echo "[plugins] WARNING: Could not download ${PLUGIN} — skipping"; \
        else \
            echo "[plugins] ${PLUGIN} already present — skipping download"; \
        fi; \
    done; \
    echo "[plugins] Plugin installation complete"

# ── Stage 2: Runtime image ────────────────────────────────────────────────────
FROM eclipse-temurin:17-jre-jammy AS runtime

LABEL maintainer="Alex Zelenski, GISP <azelenski@clearviewgeographic.com>"
LABEL org.opencontainers.image.title="CVG GeoServer Raster"
LABEL org.opencontainers.image.description="GeoServer 2.28.3 — Raster tile & grid services (ImageMosaic, GeoTIFF, COG, WMS, WCS)"
LABEL org.opencontainers.image.vendor="Clearview Geographic LLC"
LABEL org.opencontainers.image.version="2.28.3"
LABEL org.opencontainers.image.licenses="Proprietary"

# Runtime deps:
#   gdal-bin / libgdal-dev  — GDAL raster I/O (GeoTIFF, JPEG2000, NetCDF, COG)
#   libgeos-dev / libproj-dev — geometry + projection libs for WCS reprojection
#   tini                    — lightweight init (PID 1) for proper signal handling
#   fontconfig              — required by Jetty/GeoServer for label rendering
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        gdal-bin \
        libgdal-dev \
        libgeos-dev \
        libproj-dev \
        libjai-imageio-core-java \
        ca-certificates \
        fontconfig \
        tini \
    && rm -rf /var/lib/apt/lists/*

# Copy extracted GeoServer from build stage
COPY --from=extract /build/geoserver /opt/geoserver

RUN chmod +x /opt/geoserver/bin/*.sh \
    && find /opt/geoserver -name "*.sh" -exec chmod +x {} +

# ── Environment ───────────────────────────────────────────────────────────────
ENV GEOSERVER_HOME=/opt/geoserver
ENV GEOSERVER_DATA_DIR=/opt/geoserver/data_dir
ENV GEOWEBCACHE_CACHE_DIR=/opt/geowebcache_data
ENV GEOSERVER_LOG_LOCATION=/var/log/geoserver/geoserver.log

# GDAL native library path (required by gdal-plugin)
ENV GDAL_DATA=/usr/share/gdal
ENV LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}

# Public URL — set at runtime via docker-compose env to match your domain.
# Ensures WMS/WCS GetCapabilities responses contain the correct public URLs.
ENV PROXY_BASE_URL=https://raster.cleargeo.tech/geoserver

# CSRF whitelist — whitelist the public domain so Caddy-proxied admin UI works
ENV GEOSERVER_CSRF_WHITELIST=raster.cleargeo.tech

# Raster-optimized JVM settings:
#   UseContainerSupport         — respect Docker --memory limits for heap sizing
#   MaxRAMPercentage=75.0       — use up to 75% of container memory as heap
#   InitialRAMPercentage=25.0   — start at 25% to avoid over-allocating on small VMs
#   XX:+UseG1GC                 — low-pause GC ideal for tile-serving workloads
#   MaxGCPauseMillis=200        — target max GC pause for interactive tile requests
#   NewRatio=2                  — young:old gen ratio for ImageMosaic read patterns
#   -Djava.security.egd         — faster entropy source (avoids /dev/random blocking)
#   CoverageFactoryFinder=SEVERE — suppress noisy JAI coverage factory log spam
# Raster-optimized JVM — performance additions vs. baseline:
#   G1HeapRegionSize=8m         — matches large GeoTIFF/COG/mosaic tile buffer objects
#                                  (default 2-32m auto; pinning to 8m reduces humongous allocs)
#   ParallelRefProcEnabled      — parallelise reference processing in GC threads = shorter pauses
#   UseStringDeduplication      — JVM deduplicates equal strings (CRS WKT, layer names)
#   SurvivorRatio=8             — widen Eden for short-lived tile decode buffers
#   image.overview.policy=SPEED — pick best available overview band by speed not quality
#   maxFormContentSize=50MB     — Jetty request body ceiling for WCS GetCoverage POST
ENV JAVA_OPTS="-server \
    -XX:+UseContainerSupport \
    -XX:MaxRAMPercentage=75.0 \
    -XX:InitialRAMPercentage=25.0 \
    -XX:+UseG1GC \
    -XX:MaxGCPauseMillis=200 \
    -XX:NewRatio=2 \
    -XX:G1HeapRegionSize=8m \
    -XX:+ParallelRefProcEnabled \
    -XX:+UseStringDeduplication \
    -XX:SurvivorRatio=8 \
    -XX:+ExplicitGCInvokesConcurrent \
    -Djava.awt.headless=true \
    -Djava.security.egd=file:/dev/./urandom \
    -Dfile.encoding=UTF-8 \
    -Djavax.servlet.request.encoding=UTF-8 \
    -Djavax.servlet.response.encoding=UTF-8 \
    -DALLOW_ENV_PARAMETRIZATION=true \
    -Dorg.geoserver.htmlui.timeout=60 \
    -Dorg.geotools.image.overview.policy=SPEED \
    -Dorg.eclipse.jetty.server.Request.maxFormContentSize=52428800 \
    -Dorg.geotools.coverage.grid.CoverageFactoryFinder.level=SEVERE \
    -Dorg.geotools.referencing.forceXY=true \
    -XX:+AlwaysPreTouch \
    -XX:+PerfDisableSharedMem \
    -Dlog4j2.formatMsgNoLookups=true \
    -Dnetworkaddress.cache.ttl=60"

# Create log dirs, GWC cache dir, and non-root service user
RUN useradd -m -u 1001 -s /bin/bash geoserver \
    && mkdir -p /var/log/geoserver /opt/geowebcache_data \
    && chown -R geoserver:geoserver /opt/geoserver /var/log/geoserver /opt/geowebcache_data

USER geoserver

# Volumes:
#   data_dir           — GeoServer workspaces, stores, styles, layer config (MUST persist)
#   geowebcache_data   — GeoWebCache tile cache (large, optional external volume)
VOLUME ["/opt/geoserver/data_dir", "/opt/geowebcache_data"]

EXPOSE 8080

# GeoServer takes 60–120s to start on first run (data_dir init + plugin scan).
# Use /geoserver/ows (no params) — returns a tiny dispatcher page in <100ms.
# Avoids fetching the 300KB+ WMS GetCapabilities XML on every 30s probe.
# docker-compose.prod.yml overrides this at runtime with the same lightweight probe.
HEALTHCHECK --interval=30s --timeout=15s --start-period=120s --retries=5 \
    CMD curl -fsS -o /dev/null "http://localhost:8080/geoserver/ows" || exit 1

# tini as PID 1 ensures GeoServer's JVM receives SIGTERM cleanly on docker stop
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/opt/geoserver/bin/startup.sh"]
