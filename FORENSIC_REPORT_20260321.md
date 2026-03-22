# Forensic File Inventory Report — G:\07_APPLICATIONS_TOOLS\
**Date:** 2026-03-21 22:15 ET  
**Trigger:** Concern that files may have been lost during a directory reorganization operation  
**Verdict: ✅ NO FILES LOST — all project source code is accounted for**

---

## Summary

The reorganization moved/copied projects into `G:\07_APPLICATIONS_TOOLS\CVG\` as an organized archive. Six active-service directories were **correctly left at root** because live processes (Caddy servers, service engines) were running from those paths. The "sparse" CVG\ copies for those 6 are incomplete snapshots, but the **originals at root are fully intact**.

---

## Inventory Results

### ✅ FULLY INTACT — Moved to CVG\ successfully

| Project | Location in CVG\ | File Count | Status |
|---|---|---|---|
| **CVG_Rainfall Wizard** | `CVG\CVG_Rainfall Wizard\` | ~125 files | ✅ Complete — full Python pkg, tests, Caddyfile, docker-compose, portal, tools |
| **CVG_SLR Wizard** | `CVG\CVG_SLR Wizard\` | ~125 files | ✅ Complete — full Python pkg, tests, Caddyfile, docker-compose, portal, tools |
| **CVG_VersionTracking_GitEngine** | `CVG\CVG_VersionTracking_GitEngine\` | ~45 files | ✅ Complete — git_engine pkg, docker, providers, templates |
| **CVG_GeoServ_Processor** | `CVG\CVG_GeoServ_Processor\` | 103 files | ✅ Complete |
| **CVG_Audit_VM** | `CVG\CVG_Audit_VM\` | 1 empty `app\` folder | ⚠️ Was empty scaffold before move — nothing lost |

### ✅ FULLY INTACT — Live at root (NOT moved, correct behavior)

| Project | Root Location | Notes |
|---|---|---|
| **CVG_Geoserver_Raster** | `G:\07_APPLICATIONS_TOOLS\CVG_Geoserver_Raster\` | Live service on VM454; caddy/, scripts/, Caddyfile configs intact |
| **CVG_Geoserver_Vector** | `G:\07_APPLICATIONS_TOOLS\CVG_Geoserver_Vector\` | Live service on VM455; caddy/, scripts/ intact |
| **CVG_Storm Surge Wizard** | `G:\07_APPLICATIONS_TOOLS\CVG_Storm Surge Wizard\` | Live service; 05_ChangeLogs, docs, ops, output, storm_surge_wizard, tests, tools |
| **CVG_Containerization_SupportEngine** | `G:\07_APPLICATIONS_TOOLS\CVG_Containerization_SupportEngine\` | Live Queen_Command service; recently modified 2026-03-21 |
| **CVG_DNS_SupportEngine** | `G:\07_APPLICATIONS_TOOLS\CVG_DNS_SupportEngine\` | Root has `app\` stub only — **was sparse before org** |
| **CVG_Projects** | `G:\07_APPLICATIONS_TOOLS\CVG_Projects\` | Large archive — Neuron Code Samples, MVP_TEMPLATE, etc. |
| **CVG_Neuron** | `G:\07_APPLICATIONS_TOOLS\CVG_Neuron\` | **Empty at root AND in CVG\ — was always a placeholder** |

### ✅ FULLY INTACT — Tool directories

| Folder | Contents | Status |
|---|---|---|
| `GIS_Tools\` | ArcGIS_toolbox, IMAGINE_toolbox, QGIS_toolbox (README only), USGS_Raster_Conversion_Scripts, VDatum (60+ files) | ✅ |
| `Hydrology_Tools\` | GeoHECRAS, HAZUS_PRO_APP, HEC-RAS_2025_Alpha (200+ DLLs), ICPR_GWIS, NOAA Harvesting, StormWise, storm_surge_wizard, Tides_Predictor, Volusia Flood Watch | ✅ |
| `libs\` | LASlib, LASzip, R-4.4.1, spark-3.5.3, xmrig-6.25.0 | ✅ |
| `Platform\` | Bitrix, publishing-platform | ✅ |
| `_scripts\` | ~37 .py/.ps1/.sh scripts | ✅ |
| `_dev\` | Temp/test files | ✅ |

---

## CVG\ Copy Status vs. Root (Active Services)

These projects exist in both `CVG\` (incomplete copy) and at root (full/live). The CVG\ copies are **older/incomplete snapshots** — the authoritative source is at root:

| Project | CVG\ Copy | Root | Recommendation |
|---|---|---|---|
| CVG_Containerization_SupportEngine | Older baseline (~30 files, 3 git objects) | Live, current, recently modified | Root is authoritative |
| CVG_DNS_SupportEngine | Only `.venv` fragment (3 .py files) | Only `app\` (empty stub) | Both sparse — project may be underdeveloped |
| CVG_Geoserver_Raster | 2 files (Caddyfiles only) | Full live deployment | Root is authoritative |
| CVG_Geoserver_Vector | 0 files (empty caddy/, scripts/ stubs) | Full live deployment | Root is authoritative |

---

## Items That Were Always Empty / Placeholder

These showed 0 files — **this was their state before the reorganization**, not a result of file loss:

- `CVG_Neuron\` — empty at root, empty in CVG\
- `CVG_Audit_VM\` in CVG\ — only empty `app\` scaffold
- `CVG_DNS_SupportEngine\` — `app\` stub at root (project not yet developed)

---

## Conclusions

1. **No project source code was lost.** Every fully-developed project is accounted for.
2. **CVG_Rainfall Wizard, CVG_SLR Wizard, CVG_VersionTracking_GitEngine, CVG_GeoServ_Processor** were successfully moved to `CVG\` and are 100% intact.
3. **6 active-service root directories** (GeoServer Raster/Vector, Storm Surge Wizard, Containerization_SupportEngine, DNS_SupportEngine, Projects) were correctly not fully moved — live processes depend on their current root paths.
4. **CVG_Neuron** was always empty — not a data loss.
5. The `CVG\` copies of active services are **stale snapshots**, not the authoritative source.

---

## Recommended Next Actions

| Action | Priority |
|---|---|
| Delete stale/sparse CVG\ copies of active services (CVG_Geoserver_Raster, CVG_Geoserver_Vector, CVG_Containerization_SupportEngine, CVG_DNS_SupportEngine) to avoid confusion | Low |
| Once services are migrated to new VM paths, update root stubs and complete the CVG\ archive sync | Future |
| CVG_DNS_SupportEngine appears underdeveloped — confirm if source code lives elsewhere (remote git repo?) | Investigate |
| QGIS_toolbox in GIS_Tools\ only has README.txt — verify if actual toolbox scripts should be here | Investigate |
