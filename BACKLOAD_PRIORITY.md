<!--
  © Clearview Geographic LLC -- All Rights Reserved | Est. 2018
  CVG GeoServer Raster — BACKLOAD PRIORITY PLAN
  Author: Alex Zelenski, GISP | azelenski@clearviewgeographic.com
  Revised: 2026-03-22 v2.0 — Full portfolio scope (ALL geospatial data)
-->

# ⚠️ TOP PRIORITY — CVG GeoServer Raster: Full Portfolio Backload Campaign

> **Status:** 🔴 **CRITICAL — #1 ACTIVE INITIATIVE ON BOTH GEOSERVERS**
> **Author:** Alex Zelenski, GISP
> **Revised:** 2026-03-22 v2.0
> **Applies To:** CVG GeoServer Raster (`raster.cleargeo.tech`) — see sister doc for `vector.cleargeo.tech`

---

## 🚨 SCOPE NOTICE — ALL GEOSPATIAL DATA, NOT JUST SLR/STORM SURGE

> **This campaign covers 100% of geospatial raster data across ALL CVG project types from 2018–2026.**
>
> CVG's portfolio spans far beyond sea level rise and storm surge analysis. Every project that produced
> a raster output — regardless of client, discipline, or data type — must be inventoried, classified,
> processed, and published to `raster.cleargeo.tech`. This includes (but is not limited to):
>
> - 🌊 Coastal risk, SLR, storm surge depth grids ← **these are just one slice**
> - 🌲 Tree survey density / canopy rasters
> - 🦎 Habitat suitability, wildlife corridor, natural land cover
> - 💧 Wetland hydrology, drainage, DEM/elevation derivatives
> - ☀️ Solar irradiance, site analysis rasters
> - 🏙️ Municipal / county land use, impervious surface
> - 🌊 Flood zone, FEMA FIRM panel rasters
> - 🛩️ Drone/aerial orthomosaics and photogrammetric DEMs
> - 🌿 NDVI / vegetation index imagery
> - 🪨 Soils, geology reference rasters
> - 📡 Satellite/aerial imagery base products
> - 🔥 Fire risk, wildfire probability surfaces
> - 🧭 Any other raster produced for any CVG client project, 2018–2026
>
> **If it is a raster and it lives in `Z:\{year}\{project}\` — it belongs in this backload.**

---

## 🎯 Mission Statement

**The #1 priority for both GeoServer platforms is to systematically backload, categorize, and organize ALL previously collected project-specific geospatial raster data stored in the Z:\ project archive directories spanning 2018–2026.**

This initiative precedes all other GeoServer development work (SLD styling, WMS integration, API wizard, etc.). No new project data should be published until the backload inventory and publishing pipeline is operational and validated.

---

## 📂 Source Directories — Z:\ Project Archive (Priority Order)

The Z:\ drive (CGPS volume) contains ALL historical CVG project data organized by year and sequential project number. Archive structure:

```
Z:\{YEAR}\{YY##}_{ClientName}\
        ├── Aprx\            ← ArcGIS Pro project + GDB (PRIMARY GIS DATA)
        ├── Maps for Avenza\ ← Field map exports (PDFs, georeferenced)
        ├── Report\          ← Final reports (may reference rasters)
        └── *.gdb            ← File Geodatabases (rasters may be in here)
```

### Priority Loading Order

| Priority | Directory | Content Summary | Status |
|----------|-----------|-----------------|--------|
| 🔴 **P1 — CRITICAL** | `Z:\2026` | Current year jobs — 2601+ | 🔴 Not loaded |
| 🔴 **P1 — CRITICAL** | `Z:\2025` | 2501 Fire Risk → 2540 CJR (40 projects) | 🔴 Not loaded |
| 🟠 **P2 — HIGH** | `Z:\2024` | 2401 GFelix → 2413 CMurphy (13 projects) | 🔴 Not loaded |
| 🟠 **P2 — HIGH** | `Z:\2023` | 2301 Evolving Landscapes → 2335 JZyla (35 projects) | 🔴 Not loaded |
| 🟡 **P3 — MEDIUM** | `Z:\2022` | 2201 City of Deland → 2272 Coastal Eco-Group (70+ projects) | 🔴 Not loaded |
| 🟡 **P3 — MEDIUM** | `Z:\2021` | 2102 West Volusia Audubon → 2134 DFinnigan (33 projects) | 🔴 Not loaded |
| 🟢 **P4 — STANDARD** | `Z:\2020` | 2001 Edgewater Env. Alliance → 2044 JCFigueredo (44 projects) | 🔴 Not loaded |
| 🟢 **P4 — STANDARD** | `Z:\2019` | 1901 Society6 → 1937 ElliotGindi (37 projects) | 🔴 Not loaded |
| 🔵 **P5 — ARCHIVE** | `Z:\2018` | 1801 DelandCyclery → 1841 WaterFilters (founding year, 23 projects) | 🔴 Not loaded |

> **Load most recent → oldest:** 2026 → 2025 → 2024 → … → 2018
> Most relevant, active client data becomes available immediately.

---

## 🗂️ CVG Project Type Taxonomy — Raster Data

The following project types exist in the Z:\ archive. Each type maps to expected raster outputs:

### Tier A — Environmental / Ecological

| Project Type | Expected Raster Data | GeoServer Type Code |
|--------------|---------------------|---------------------|
| Wetland Delineation | DEM, hydrology grids, NDVI, aerial base | `wetland` |
| Habitat Evaluation / Wildlife Corridor | Habitat suitability, land cover, NDVI | `habitat` |
| Aquatic / Water Quality | Bathymetry, water depth, turbidity rasters | `aquatic` |
| Fire Risk Assessment | Fire probability, fuel load, severity rasters | `fire` |
| Native Landscape / Restoration | Land cover, canopy cover, vegetation index | `vegetation` |

### Tier B — Coastal / Flood / Climate

| Project Type | Expected Raster Data | GeoServer Type Code |
|--------------|---------------------|---------------------|
| Coastal Risk / SLR Vulnerability | Depth grids, inundation extents (raster) | `slr` |
| Storm Surge / Flood Analysis | Water depth grids, surge scenario rasters | `surge` |
| Floodplain / FEMA Compliance | FIRM panel rasters, BFE surfaces | `flood` |
| PPBERP / Vulnerability Assessment | Hazard index rasters, exposure surfaces | `vuln` |

### Tier C — Property / Development / Municipal

| Project Type | Expected Raster Data | GeoServer Type Code |
|--------------|---------------------|---------------------|
| Statistical Tree / Canopy Survey | Canopy raster, density grids, ortho imagery | `treesurvey` |
| Solar Site Analysis | Irradiance rasters, shading analysis | `solar` |
| Due Diligence / Environmental DD | Aerial imagery, land use rasters | `duediligence` |
| City / County Municipal GIS | Land use, zoning, impervious surface | `municipal` |
| Wetland / Stormwater Engineering | DEM, flow accumulation, drainage rasters | `stormwater` |

### Tier D — Imagery / Survey / Reference

| Project Type | Expected Raster Data | GeoServer Type Code |
|--------------|---------------------|---------------------|
| Drone / Aerial Orthomosaic | GeoTIFF orthomosaic, photogrammetric DEM | `ortho` |
| LiDAR / Elevation Products | Bare earth DEM, DSM, intensity raster | `dem` |
| Satellite Imagery | Multispectral imagery, classification output | `imagery` |
| Aerial Photo Base Layer | Historical aerial, reference imagery | `aerial` |
| Soil / Geology Reference | SSURGO-derived rasters, geology index | `soils` |

---

## 🏷️ GeoServer Raster Naming Convention

All published raster layers must follow this naming scheme **from day one — no exceptions:**

```
Workspace:  cvg
Layer Name: cvg:{typeCode}_{projectSlug}_{year}[_{variant}]

Where:
  typeCode    = from CVG Project Type Taxonomy above (e.g., wetland, surge, treesurvey)
  projectSlug = derived from Z:\ folder name, lowercased, spaces→underscores
                e.g.: "2505 Seebeck WD"       → seebeck_wd
                      "2401 GFelix"            → gfelix
                      "2307 FDOT"              → fdot
                      "2024 FL Mitigation"     → fl_mitigation
                      "2522 Armino"            → armino
  year        = 4-digit project year
  variant     = optional scenario/sub-type (cat3, 2ft, lidar, spring2025, etc.)
```

### Layer Naming Examples (Real CVG Projects)

```
cvg:wetland_seebeck_wd_2025_dem          ← 2505 Seebeck Wetland Delineation — elevation
cvg:habitat_wcorridor_volusia_2025       ← Volusia Wildlife Corridor habitat suitability
cvg:treesurvey_gfelix_2024_canopy        ← 2401 GFelix Statistical Tree Survey — canopy
cvg:treesurvey_osmin_2024_density        ← 2408 Osmin Tree Survey — density grid
cvg:fire_holden_nash_2025                ← 2501 Holden Nash Fire Risk surface
cvg:surge_fbslrva_2019                   ← 1932 FBSLRVA storm surge grid
cvg:slr_monroe_county_2019               ← 1935 Monroe County SLR depth
cvg:flood_martin_county_2018             ← 1836 Martin County FEMA flood surface
cvg:solar_mysolarrooftop_2018            ← 1830 MySolarRooftop irradiance raster
cvg:dem_sjrwmd_2020                      ← 2016 SJRWMD elevation product
cvg:ortho_drones_on_demand_2022          ← 2244 Drones on Demand orthomosaic
cvg:municipal_city_deland_2022           ← 2201 City of Deland land use raster
cvg:aquatic_ocean_habitats_2020          ← 2019 Ocean Habitats bathymetry
cvg:vuln_ppberp_2025                     ← 2524 PPBERP Vulnerability Assessment
cvg:municipal_city_palatka_2025          ← 2520 City of Palatka municipal raster
cvg:coastal_captains_clean_water_2023    ← 2305 Captains for Clean Water
cvg:municipal_fdot_2023                  ← 2307 FDOT project raster output
cvg:habitat_riverside_conservancy_2021   ← 2122 Riverside Conservancy habitat
```

---

## 🗂️ Backload Workflow — Phase by Phase

### Phase 1 — Inventory (Run FIRST for Every Year)

**Use the PowerShell inventory script** (required since Z:\ is Windows/SMB):

```powershell
# Run from any workstation with Z:\ mapped:
# Usage: .\scripts\backload_inventory.ps1 -Year 2026

# The script walks the full year directory and outputs two CSV inventory files:
#   backload_inventory_{YEAR}_rasters.csv
#   backload_inventory_{YEAR}_all_geospatial.csv

powershell -ExecutionPolicy Bypass -File "G:\07_APPLICATIONS_TOOLS\CVG_Geoserver_Raster\scripts\backload_inventory.ps1" -Year 2026
```

**Raster file extensions to capture:**
```
.tif  .tiff  .img  .dem  .asc  .grd  .flt  .hgt
.nc   .vrt   .sid  .ecw  .jp2  .mrf
```

**Also flag GDB rasters** — ArcGIS GDBs frequently contain raster datasets and mosaic datasets. These require ArcPy or GDAL to extract:
```powershell
# Find all GDBs (likely contain rasters for many CVG project types):
Get-ChildItem "Z:\2026" -Recurse -Directory -Filter "*.gdb" |
  Select-Object FullName | Export-Csv backload_inventory_2026_gdbs.csv
```

**Inventory Completion Checklist:**
- [ ] `Z:\2026` — inventory complete
- [ ] `Z:\2025` — inventory complete
- [ ] `Z:\2024` — inventory complete
- [ ] `Z:\2023` — inventory complete
- [ ] `Z:\2022` — inventory complete
- [ ] `Z:\2021` — inventory complete
- [ ] `Z:\2020` — inventory complete
- [ ] `Z:\2019` — inventory complete
- [ ] `Z:\2018` — inventory complete

---

### Phase 2 — Categorization (Classify Each Dataset)

After inventory CSV is generated, classify each raster using these fields:

| Field | Values |
|-------|--------|
| **Project Year** | 2018–2026 |
| **Project Number** | YYNN format (e.g., `2505`, `2401`) |
| **Project Slug** | Derived from folder name (lowercased, no special chars) |
| **Client/Project Name** | Full client/project name from folder |
| **CVG Type Code** | from taxonomy table above (`wetland`, `surge`, `treesurvey`, etc.) |
| **Original Format** | `.tif`, `.img`, `.dem`, `.gdb_raster`, etc. |
| **Source Path** | Full Z:\ path |
| **CRS (EPSG)** | Verify with `gdalinfo`; note if unknown |
| **Pixel Resolution** | e.g., 1m, 3m, 30m |
| **COG Ready?** | `yes` · `no — needs conversion` |
| **Publish Priority** | `high` (recent/active) · `medium` · `archive` (2018–2020) |

---

### Phase 3 — Processing (COG Conversion)

All rasters must be converted to **Cloud Optimized GeoTIFF (COG)** before publishing to GeoServer:

```bash
# COG conversion via GDAL (run on VM/Linux with Z:\ mounted or after copy to NAS):
gdal_translate \
  -of COG \
  -co COMPRESS=DEFLATE \
  -co PREDICTOR=2 \
  -co OVERVIEWS=IGNORE_EXISTING \
  -co RESAMPLING=NEAREST \
  "Z:/2026/{project}/{file}.tif" \
  "/mnt/cgdp/backload/2026/{projectSlug}/{layername}_cog.tif"

# Reproject + COG in one step (if CRS needs correction):
gdalwarp -t_srs EPSG:4326 -of COG \
  -co COMPRESS=DEFLATE -co PREDICTOR=2 \
  "Z:/2026/{project}/{file}.tif" \
  "/mnt/cgdp/backload/2026/{projectSlug}/{layername}_4326_cog.tif"

# Verify COG structure:
gdalinfo "/mnt/cgdp/backload/2026/{projectSlug}/{layername}_cog.tif" | grep -E "LAYOUT|Overviews"
```

**GDB Raster extraction (requires GDAL with FileGDB driver or ArcPy):**
```bash
# List raster datasets inside a GDB:
gdalinfo "Z:/2026/{project}/Aprx/{project}.gdb"
# Then extract each:
gdal_translate "Z:/2026/{project}/Aprx/{project}.gdb/{raster_name}" output_cog.tif -of COG
```

**Processing Checklist (per raster file):**
- [ ] CRS verified (`gdalinfo` — record EPSG)
- [ ] Reproject to EPSG:4326 if needed
- [ ] Convert to COG (DEFLATE compressed, overviewed)
- [ ] Verify COG: `LAYOUT=COG` confirmed in `gdalinfo`
- [ ] Saved to `/mnt/cgdp/backload/{year}/{projectSlug}/`
- [ ] Entry logged in `backload_raster_processing_log.csv`

---

### Phase 4 — Publishing (GeoServer REST API)

```bash
GS_BASE="https://raster.cleargeo.tech/geoserver/rest"
WS="cvg"
PW=$GEOSERVER_ADMIN_PASSWORD

# Step 1: Create coverage store
curl -u admin:$PW -X POST \
  -H "Content-Type: application/json" \
  -d "{
    \"coverageStore\": {
      \"name\": \"wetland_seebeck_wd_2025_dem\",
      \"type\": \"GeoTIFF\",
      \"url\": \"file:///mnt/cgdp/backload/2025/seebeck_wd/wetland_seebeck_wd_2025_dem_cog.tif\",
      \"workspace\": {\"name\": \"cvg\"},
      \"enabled\": true
    }
  }" \
  "$GS_BASE/workspaces/$WS/coveragestores"

# Step 2: Publish coverage layer from store
curl -u admin:$PW -X POST \
  -H "Content-Type: application/json" \
  -d "{\"coverage\": {
    \"name\": \"wetland_seebeck_wd_2025_dem\",
    \"title\": \"Seebeck Wetland Delineation 2025 — DEM\",
    \"abstract\": \"Elevation raster for Seebeck wetland delineation project (CVG 2505, 2025). CRS: EPSG:4326.\"
  }}" \
  "$GS_BASE/workspaces/$WS/coveragestores/wetland_seebeck_wd_2025_dem/coverages"

# Step 3: Verify via WMS GetMap
curl "https://raster.cleargeo.tech/geoserver/wms?service=WMS&version=1.3.0\
&request=GetMap&layers=cvg:wetland_seebeck_wd_2025_dem\
&bbox=-81.5,29.0,-81.0,29.5&width=256&height=256\
&srs=EPSG:4326&format=image/png" -o test_wetland_seebeck.png
```

---

### Phase 5 — Organization (GeoServer Layer Groups)

All published layers must be organized into GeoServer layer groups by year AND by CVG project type:

```
cvg (workspace)
├── BL_2026_All           ← all 2026 backloaded rasters
│   ├── BL_2026_Wetland   ← wetland delineation rasters
│   ├── BL_2026_Habitat   ← habitat / wildlife rasters
│   ├── BL_2026_Solar     ← solar analysis rasters
│   ├── BL_2026_Municipal ← city/county GIS rasters
│   └── BL_2026_Coastal   ← coastal/flood/SLR rasters
├── BL_2025_All
├── BL_2024_All
│   ...
└── BL_2018_All
```

---

## 📊 Master Raster Backload Register

> Update this table as each raster is processed and published. Export to `backload_raster_register.csv`.

| # | Year | Proj# | Project Name | File/Layer | Type Code | CRS | COG? | Published? | Layer Name | Notes |
|---|------|-------|-------------|------------|-----------|-----|------|------------|------------|-------|
| 1 | 2026 | 2601 | See 2540 CRJ Concrete | — | — | — | ❌ | ❌ | — | Inventory pending |
| 2 | 2026 | 2602 | City of Sacramento CA | — | — | — | ❌ | ❌ | — | Inventory pending |
| 3 | 2025 | 2501 | Holden Nash / Fire Risk | — | fire | — | ❌ | ❌ | — | Inventory pending |
| 4 | 2025 | 2524 | PPBERP Vuln. Assessment | — | vuln | — | ❌ | ❌ | — | Inventory pending |
| 5 | 2025 | 2505 | Seebeck WD | — | wetland | — | ❌ | ❌ | — | GDB found, extract rasters |
| 6 | 2025 | 2517 | Marine Science Center | — | aquatic | — | ❌ | ❌ | — | Inventory pending |
| 7 | 2024 | 2401 | G. Felix Stat. Tree Survey | — | treesurvey | — | ❌ | ❌ | — | GDB found |
| 8 | 2024 | 2408 | Osmin Tree Survey | — | treesurvey | — | ❌ | ❌ | — | Inventory pending |
| 9 | 2023 | 2307 | FDOT | — | municipal | — | ❌ | ❌ | — | Inventory pending |
| 10 | 2023 | 2305 | Captains for Clean Water | — | coastal | — | ❌ | ❌ | — | Inventory pending |
| 11 | 2023 | 2325 | Treasure Coast RPC | — | municipal | — | ❌ | ❌ | — | Inventory pending |
| 12 | 2022 | 2201 | City of Deland | — | municipal | — | ❌ | ❌ | — | Inventory pending |
| 13 | 2022 | 2244 | Drones on Demand | — | ortho | — | ❌ | ❌ | — | Drone ortho expected |
| 14 | 2022 | 2264 | Stantec | — | — | — | ❌ | ❌ | — | Inventory pending |
| 15 | 2021 | 2102 | West Volusia Audubon | — | habitat | — | ❌ | ❌ | — | Inventory pending |
| 16 | 2021 | 2122 | Riverside Conservancy | — | habitat | — | ❌ | ❌ | — | Inventory pending |
| 17 | 2021 | 2126 | Climate Reality Project | — | — | — | ❌ | ❌ | — | Inventory pending |
| 18 | 2020 | 2003 | Coastal Risk Consultants | — | coastal | — | ❌ | ❌ | — | Inventory pending |
| 19 | 2020 | 2016 | SJRWMD | — | dem | — | ❌ | ❌ | — | Elevation data expected |
| 20 | 2020 | 2019 | Ocean Habitats | — | aquatic | — | ❌ | ❌ | — | Bathymetry expected |
| 21 | 2020 | 2037 | Native Florida Landscapes | — | vegetation | — | ❌ | ❌ | — | Inventory pending |
| 22 | 2019 | 1932 | FBSLRVA | — | slr | — | ❌ | ❌ | — | SLR depth grids expected |
| 23 | 2019 | 1935 | Monroe County | — | flood | — | ❌ | ❌ | — | Inventory pending |
| 24 | 2019 | 1926 | Volusia County | — | municipal | — | ❌ | ❌ | — | Inventory pending |
| 25 | 2018 | 1836 | Martin County | — | municipal | — | ❌ | ❌ | — | Inventory pending |
| 26 | 2018 | 1840 | Nassau County | — | municipal | — | ❌ | ❌ | — | Inventory pending |
| 27 | 2018 | 1830 | MySolarRooftop | — | solar | — | ❌ | ❌ | — | Solar raster expected |
| … | … | … | … | … | … | … | … | … | … | … |

---

## 🔧 Scripts Required

| Script | Purpose | Location | Status |
|--------|---------|----------|--------|
| `backload_inventory.ps1` | PowerShell: walk Z:\ year → raster inventory CSV | `scripts/` | ⬜ Created (see scripts/) |
| `backload_inventory_gdbs.ps1` | PowerShell: find all GDBs per year for raster extraction | `scripts/` | ⬜ Created |
| `backload_cog_convert.sh` | Bash: batch COG conversion via gdal_translate | `scripts/` | ⬜ Created |
| `backload_publish_raster.sh` | Bash: REST API publish coverage store + layer | `scripts/` | ⬜ TODO |
| `backload_verify_raster.sh` | Bash: WMS GetMap smoke test per layer | `scripts/` | ⬜ TODO |
| `backload_layer_group.sh` | Bash: create GeoServer layer groups per year+type | `scripts/` | ⬜ TODO |

---

## ⚡ Immediate Start Sequence

> **Begin here — right now — before any other GeoServer work:**

```
STEP 1 ─── Run inventory script for Z:\2026
           powershell -File scripts/backload_inventory.ps1 -Year 2026
           → Produces: backload_inventory_2026_rasters.csv

STEP 2 ─── Open CSV, review each row
           Assign: TypeCode, ProjectSlug, PublishPriority
           Flag GDB-embedded rasters for extraction

STEP 3 ─── Copy raw files from Z:\2026 → NAS staging area
           \\10.10.10.100\cgps\backload\2026\{projectSlug}\

STEP 4 ─── Run COG conversion on all non-COG rasters
           bash scripts/backload_cog_convert.sh 2026
           → Output: /mnt/cgdp/backload/2026/{projectSlug}/*_cog.tif

STEP 5 ─── Verify CVG workspace exists in GeoServer raster
           curl -u admin:$PW https://raster.cleargeo.tech/geoserver/rest/workspaces/cvg

STEP 6 ─── Publish first high-priority batch (2026 + 2025)
           bash scripts/backload_publish_raster.sh 2026

STEP 7 ─── Repeat for 2025 → 2024 → 2023 → ... → 2018
```

---

## 📋 Priority Summary Card

```
╔══════════════════════════════════════════════════════════════════════╗
║  CVG GEOSERVER RASTER — FULL PORTFOLIO BACKLOAD PRIORITY            ║
║  ────────────────────────────────────────────────────────────────    ║
║                                                                       ║
║  ⚠  SCOPE: ALL CVG GEOSPATIAL RASTER DATA — NOT JUST SLR/SURGE ⚠   ║
║     Wetlands · Tree Surveys · Habitat · Solar · Municipal ·          ║
║     Coastal Risk · Drone Ortho · DEM · Fire Risk · + MORE            ║
║                                                                       ║
║  🔴 P1 — CRITICAL:  Z:\2026  →  Load NOW (current year)             ║
║  🔴 P1 — CRITICAL:  Z:\2025  →  Load NOW (40 projects)              ║
║  🟠 P2 — HIGH:      Z:\2024  →  Load NEXT (13 projects)             ║
║  🟠 P2 — HIGH:      Z:\2023  →  Load NEXT (35 projects)             ║
║  🟡 P3 — MEDIUM:    Z:\2022  →  After P2 (70+ projects)             ║
║  🟡 P3 — MEDIUM:    Z:\2021  →  After P2 (33 projects)              ║
║  🟢 P4 — STANDARD:  Z:\2020  →  Batch with 2019 (44 projects)       ║
║  🟢 P4 — STANDARD:  Z:\2019  →  Batch with 2020 (37 projects)       ║
║  🔵 P5 — ARCHIVE:   Z:\2018  →  Last (founding year, 23 projects)   ║
║                                                                       ║
║  DATA FLOW:  Z:\  →  NAS Staging  →  COG Convert  →  GeoServer     ║
║  ENDPOINT:   https://raster.cleargeo.tech/geoserver/wms             ║
╚══════════════════════════════════════════════════════════════════════╝
```

---

## Related Documents

| Document | Location |
|----------|----------|
| Vector Backload Plan | `CVG_Geoserver_Vector/BACKLOAD_PRIORITY.md` |
| Raster GeoServer Roadmap | `ROADMAP.md` |
| GeoServer Init Script | `scripts/geoserver-init.sh` |
| Inventory Script (PowerShell) | `scripts/backload_inventory.ps1` |
| COG Conversion Script | `scripts/backload_cog_convert.sh` |
| Changelog | `05_ChangeLogs/master_changelog.md` |
| Z:\ Master Status | `Z:\CVG_MASTER_ACTION_PLAN.md` |

---

*CVG GeoServer Raster Backload Priority v2.0 — Revised 2026-03-22*
*Scope expanded from coastal-only to FULL CVG portfolio (all geospatial raster data, 2018–2026)*
*© Clearview Geographic, LLC — Proprietary — CVG-ADF*
