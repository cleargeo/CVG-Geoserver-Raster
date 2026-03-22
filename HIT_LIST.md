<!--
  © Clearview Geographic LLC -- All Rights Reserved | Est. 2018
  CVG Platform — Highest Priority Hit List
  Author: Alex Zelenski, GISP | azelenski@clearviewgeographic.com
-->

# 🎯 CVG Platform — Highest Priority Hit List

> **This is the action list. Open this first. Do these in order. Do not skip ahead.**
> Full detail → [`CVG_PLATFORM_ROADMAP.md`](CVG_PLATFORM_ROADMAP.md) | Backload detail → [`BACKLOAD_PRIORITY.md`](BACKLOAD_PRIORITY.md)
> Last updated: 2026-03-22 | ChangeID: `20260322-AZ-hitlist`

---

## ⚡ THE TOP 10 — Execute In This Exact Order

---

### #1 — ✅ COMPLETE — GeoServer Init on Both VMs
**Completed:** 2026-03-22 02:17 ET | **Time taken:** ~15 min (all steps automated)
> Admin password changed (HTTP 200), global metadata set, `cvg` workspace created (HTTP 201), sentinel written on both VMs.
> Raster: `admin:CVGRaster2026Secure` | Vector: `admin:CVGVector2026Secure`
> .env written to `/opt/cvg/CVG_Geoserver_Raster/.env` and `/opt/cvg/CVG_Geoserver_Vector/.env`
```bash
# VM 454 — Raster GeoServer:
ssh ubuntu@10.10.10.203
cd /opt/cvg/CVG_Geoserver_Raster
echo "GEOSERVER_ADMIN_PASSWORD=<strong_password>" >> .env
bash scripts/geoserver-init.sh --prod

# VM 455 — Vector GeoServer:
ssh ubuntu@10.10.10.204
cd /opt/cvg/CVG_Geoserver_Vector
echo "GEOSERVER_ADMIN_PASSWORD=<strong_password>" >> .env
bash scripts/geoserver-init.sh --prod
```
**Why #1:** Admin password is still `admin/geoserver`. Platform is publicly exposed with default credentials. No layers can be published until `cvg` workspace exists. This takes 2 hours and unblocks everything else.

---

### #2 — ✅ COMPLETE — NAS Mounts Verified Inside Both Containers
**Completed:** 2026-03-22 02:13 ET
> `/mnt/cgps` and `/mnt/cgdp` confirmed readable inside both `geoserver-raster` (VM 454) and `geoserver-vector` (VM 455) containers.
> Contents verified: 2018–2025 project directories and reference data visible on both mounts.
```bash
# From DFORGE-100:
ssh ubuntu@10.10.10.203 "docker exec geoserver-raster gdalinfo /mnt/cgps/"
ssh ubuntu@10.10.10.203 "docker exec geoserver-raster gdalinfo /mnt/cgdp/"
ssh ubuntu@10.10.10.204 "docker exec geoserver-vector ogrinfo /mnt/cgps/ --formats"
ssh ubuntu@10.10.10.204 "docker exec geoserver-vector ogrinfo /mnt/cgdp/ --formats"
```
**Why #2:** If NAS paths fail inside containers, zero data stores can be registered. Must confirm before touching GeoServer data configuration.

---

### #3 — 🔴 Inventory Z:\2026 — First Backload Year
**Time:** ~1 hour | **Blocks:** Knowing what data exists
```powershell
# Run from Windows workstation with Z:\ mapped:
Get-ChildItem -Path "Z:\2026" -Recurse -Include "*.tif","*.tiff","*.img","*.dem" |
  Select-Object FullName,Length,LastWriteTime |
  Export-Csv "C:\Temp\backload_2026_rasters.csv" -NoTypeInformation

Get-ChildItem -Path "Z:\2026" -Recurse -Include "*.shp","*.gpkg","*.geojson","*.gdb" |
  Select-Object FullName,Length,LastWriteTime |
  Export-Csv "C:\Temp\backload_2026_vectors.csv" -NoTypeInformation
```
**Why #3:** You cannot process data you cannot see. The inventory is the single input that drives everything — COG conversion, GPKG conversion, naming, and publishing decisions for Z:\2026. Do 2026 first because it is the most current and most impactful.

---

### #4 — 🟠 Publish First SSW Depth Grid — Get ONE Layer Online
**Time:** ~2 hours | **Blocks:** Portal usefulness, client demos
```bash
# COG convert one depth grid:
gdal_translate -of COG -co COMPRESS=DEFLATE -co PREDICTOR=2 \
  "Z:/2026/{project}/depth.tif" \
  "/mnt/cgdp/backload/2026/{project}/depth_cog.tif"

# Register in GeoServer via REST:
PW=$GEOSERVER_ADMIN_PASSWORD
curl -u admin:$PW -X POST \
  -H "Content-Type: application/json" \
  -d '{"coverageStore":{"name":"ssw_hca2024_cat3","type":"GeoTIFF","url":"file:///mnt/cgdp/backload/2026/hca2024/depth_cog.tif","workspace":{"name":"cvg"},"enabled":true}}' \
  "https://raster.cleargeo.tech/geoserver/rest/workspaces/cvg/coveragestores"

# Verify WMS tile renders:
curl "https://raster.cleargeo.tech/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap\
&LAYERS=cvg:ssw_hca2024_cat3&FORMAT=image/png&CRS=EPSG:4326&WIDTH=512&HEIGHT=512\
&BBOX=28,-92,32,-88&STYLES=" -o /tmp/test_tile.png && echo "✅ WMS OK"
```
**Why #4:** The portal is live, Caddy is configured, GeoServer is running — but there are zero layers. Publishing *one* layer proves the full stack works end-to-end and makes every subsequent backload layer a simple repeat.

---

### #5 — 🟠 Publish First Vector Layer — Surge Extent or AOI Boundary
**Time:** ~1 hour | **Blocks:** Vector portal, WFS clients
```bash
# GPKG convert surge extent shapefile:
ogr2ogr -f GPKG -t_srs EPSG:4326 \
  "/mnt/cgdp/backload/2026/{project}/surge_extent_cat3.gpkg" \
  "Z:/2026/{project}/surge_extent_cat3.shp"

# Register datastore on vector GeoServer:
curl -u admin:$PW -X POST \
  -H "Content-Type: application/json" \
  -d '{"dataStore":{"name":"surge_extent_hca2024","connectionParameters":{"entry":[{"@key":"database","$":"file:///mnt/cgdp/backload/2026/hca2024/surge_extent_cat3.gpkg"},{"@key":"dbtype","$":"geopkg"}]}}}' \
  "https://vector.cleargeo.tech/geoserver/rest/workspaces/cvg/datastores"

# Verify WFS:
curl "https://vector.cleargeo.tech/geoserver/wfs?SERVICE=WFS&VERSION=2.0.0\
&REQUEST=GetFeature&typeNames=cvg:surge_extent_hca2024_cat3&count=1\
&outputFormat=application/json" | python -m json.tool | head -30
```
**Why #5:** Same logic as #4 — one vector layer proves the vector pipeline. Then the rest of the 2026 backload is a batch operation.

---

### #6 — 🟠 Batch COG + Publish All Z:\2026 Rasters
**Time:** Half-day to full day | **Blocks:** 2026 backload completion
```bash
# Create the batch script once, run it against the inventory CSV from #3:
while IFS=, read -r filepath size date; do
  project=$(echo "$filepath" | awk -F/ '{print $(NF-2)}')
  filename=$(basename "$filepath" .tif)
  out="/mnt/cgdp/backload/2026/$project/${filename}_cog.tif"
  mkdir -p "/mnt/cgdp/backload/2026/$project"
  gdal_translate -of COG -co COMPRESS=DEFLATE -co PREDICTOR=2 "$filepath" "$out"
  echo "✅ COG: $out"
done < /tmp/backload_2026_rasters.csv
# Then run backload_publish_raster.sh against each output file
```
**Why #6:** Z:\2026 is P1-CRITICAL. All 2026 surge depth grids, SLR grids, DEMs, and reference rasters should be online before moving to 2025.

---

### #7 — 🟠 Batch GPKG + Publish All Z:\2026 Vectors
**Time:** Half-day | **Blocks:** 2026 vector backload completion
```bash
while IFS=, read -r filepath size date; do
  project=$(echo "$filepath" | awk -F/ '{print $(NF-2)}')
  filename=$(basename "$filepath" .shp)
  out="/mnt/cgdp/backload/2026/$project/${filename}.gpkg"
  mkdir -p "/mnt/cgdp/backload/2026/$project"
  ogr2ogr -f GPKG -t_srs EPSG:4326 "$out" "$filepath"
  echo "✅ GPKG: $out"
done < /tmp/backload_2026_vectors.csv
# Then run backload_publish_vector.sh against each output file
```
**Why #7:** Completes full 2026 backload. Once 2026 is done, repeat #3–#7 for Z:\2025.

---

### #8 — 🟠 Repeat Backload for Z:\2025 → Z:\2023 (P1 + P2 Years)
**Time:** 2–5 days | **Blocks:** Historical project layer access
```
Repeat the sequence:
  → Inventory Z:\2025 (rasters + vectors)
  → COG convert all rasters → /mnt/cgdp/backload/2025/
  → GPKG convert all vectors → /mnt/cgdp/backload/2025/
  → Publish to raster.cleargeo.tech + vector.cleargeo.tech
  → Create GeoServer layer group: cvg:BL_2025_All

Repeat for Z:\2024, Z:\2023.
Z:\2022 and earlier = P3/P4 — batch after the above.
```
**Why #8:** 2025–2023 = 4 years of active projects. Engineers and clients need these layers. 2022 and older can wait.

---

### #9 — 🟠 FEMA NFHL Flood Zones + BFE Lines Online
**Time:** M (3–5 days) | **Blocks:** Regulatory overlays on every project
```bash
# Download FEMA NFHL for project states/counties (FEMA MSC API):
# https://msc.fema.gov/api/open/v1/floodoverlays?limit=10&stateCode=LA

# Alternatively from /mnt/cgps/fema/ if already on NAS:
ogrinfo /mnt/cgps/fema/ -al -so  # verify what's available

# Convert to GPKG + publish to vector GeoServer:
ogr2ogr -f GPKG -t_srs EPSG:4326 /mnt/cgdp/reference/fema/sfha_la.gpkg \
  /mnt/cgps/fema/LA_SFHA.shp

# Register as permanent reference layer:
# cvg:fema_sfha_la  (Special Flood Hazard Area polygons — AE, AO, X zones)
# cvg:fema_bfe_la   (Base Flood Elevation lines)
# cvg:fema_panels_la (DFIRM map panel boundaries)
```
**Why #9:** Required context on 100% of CVG projects. Publishing once as a permanent WMS/WFS layer eliminates per-project FEMA data handling. Every engineer and client benefits immediately.

---

### #10 — 🟢 Set Up Health Monitoring + Backup Crons — Both VMs
**Time:** ~1 hour | **Blocks:** Nothing (but prevents future disasters)
```bash
# On VM 454:
(crontab -l 2>/dev/null; echo "*/5 * * * * bash /opt/cvg/CVG_Geoserver_Raster/scripts/health-check.sh --prod > /tmp/hc_raster.log 2>&1 || curl -s -X POST \$DISCORD_WEBHOOK -d '{\"content\":\"🔴 raster.cleargeo.tech FAILED\"}'") | crontab -
(crontab -l 2>/dev/null; echo "0 2 * * * bash /opt/cvg/CVG_Geoserver_Raster/scripts/backup.sh --dest /mnt/cgdp/backups/geoserver-raster --keep 14") | crontab -

# On VM 455:
(crontab -l 2>/dev/null; echo "*/5 * * * * bash /opt/cvg/CVG_Geoserver_Vector/scripts/health-check.sh --prod > /tmp/hc_vector.log 2>&1 || curl -s -X POST \$DISCORD_WEBHOOK -d '{\"content\":\"🔴 vector.cleargeo.tech FAILED\"}'") | crontab -
(crontab -l 2>/dev/null; echo "0 2 * * * bash /opt/cvg/CVG_Geoserver_Vector/scripts/backup.sh --dest /mnt/cgdp/backups/geoserver-vector --keep 14") | crontab -
```
**Why #10:** With real data now published, a platform failure = data inaccessibility for clients. 1 hour of setup prevents weeks of recovery time.

---

## 📋 Hit List Summary Card

```
╔═════════════════════════════════════════════════════════════════╗
║  CVG PLATFORM — TOP 10 HIT LIST                                 ║
║  ─────────────────────────────────────────────────────────────  ║
║  #1  🔴 GeoServer admin init — BOTH VMs NOW          (2 hrs)   ║
║  #2  🔴 NAS CIFS mount verify — containers           (30 min)  ║
║  #3  🔴 Inventory Z:\2026 — CSV of all files         (1 hr)    ║
║  #4  🟠 Publish FIRST depth grid raster → WMS        (2 hrs)   ║
║  #5  🟠 Publish FIRST surge extent vector → WFS      (1 hr)    ║
║  #6  🟠 Batch COG all Z:\2026 rasters → publish      (1 day)   ║
║  #7  🟠 Batch GPKG all Z:\2026 vectors → publish     (½ day)   ║
║  #8  🟠 Repeat for Z:\2025 → Z:\2023                 (3 days)  ║
║  #9  🟠 FEMA NFHL flood zones + BFE online           (3 days)  ║
║  #10 🟢 Health monitoring + backup crons             (1 hr)    ║
║                                                                   ║
║  TOTAL ESTIMATED TIME:  ~10 working days to hit #1–10            ║
║  RESULT:  4+ years of CVG data live on OGC services             ║
╚═════════════════════════════════════════════════════════════════╝
```

---

## ⏭️ After The Top 10 — Next Up

Once #1–#10 are done, the next sprint targets are:

| Next | Feature | Why |
|------|---------|-----|
| #11 | `CVG_GeoServ_Processor` Python pipeline | Auto-publish after every wizard run — eliminates manual steps forever |
| #12 | SSW auto-publish hook in `web_api.py` | Depth grid + flood extent published automatically post-run |
| #13 | CVG Dash WMS tile overlay | Engineers and clients see results inside the wizard UI instantaneously |
| #14 | Client project portal `/portal/{project}/` | Clients self-serve their project maps without CVG involvement |
| #15 | SLR WMS TIME dimension + Dash year slider | Animated SLR year progression — headline client deliverable |

---

*CVG Platform Hit List v1.0.0 — Issued 2026-03-22 (Session 13)*
*© Clearview Geographic, LLC — Proprietary — CVG-ADF*
