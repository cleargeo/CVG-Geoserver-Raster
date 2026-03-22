#!/usr/bin/env bash
# =============================================================================
# CVG GeoServer Raster — Backload COG Conversion Script
# Author: Alex Zelenski, GISP | Clearview Geographic LLC
# Version: 1.0.0 | 2026-03-22
#
# PURPOSE:
#   Batch-convert ALL raster files for a given project year from raw format
#   to Cloud Optimized GeoTIFF (COG) for publishing to raster.cleargeo.tech.
#   Handles ALL CVG raster types — not just coastal/SLR data.
#
# REQUIREMENTS:
#   - GDAL >= 3.1 (gdal_translate, gdalinfo, gdalwarp)
#   - Read access to Z:\ (or local copy on NAS)
#   - Write access to /mnt/cgdp/backload/ (or BACKLOAD_OUTPUT_DIR)
#
# USAGE:
#   bash backload_cog_convert.sh <YEAR> [INPUT_DIR] [OUTPUT_DIR]
#
# EXAMPLES:
#   bash backload_cog_convert.sh 2026
#   bash backload_cog_convert.sh 2025 /mnt/cgps/backload/2025 /mnt/cgdp/backload/2025
#   bash backload_cog_convert.sh 2024 "Z:/2024" "/mnt/cgdp/backload/2024"
# =============================================================================

set -euo pipefail

YEAR="${1:?Usage: $0 <YEAR> [INPUT_DIR] [OUTPUT_DIR]}"
INPUT_BASE="${2:-/mnt/cgps/backload/${YEAR}}"
OUTPUT_BASE="${3:-/mnt/cgdp/backload/${YEAR}}"
LOG_FILE="backload_cog_convert_${YEAR}_$(date +%Y%m%d_%H%M%S).log"
PROCESSING_LOG="backload_raster_processing_log.csv"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Raster extensions to convert
RASTER_EXTENSIONS="tif tiff img dem asc grd flt hgt nc vrt sid ecw jp2 mrf"

# Target CRS for all published rasters
TARGET_CRS="EPSG:4326"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; ORANGE='\033[0;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'

# ── Logging ───────────────────────────────────────────────────────────────────
log() { echo -e "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
log_success() { log "${GREEN}✓${NC} $*"; }
log_warn()    { log "${ORANGE}⚠${NC} $*"; }
log_error()   { log "${RED}✗${NC} $*"; }
log_section() { log "${CYAN}══ $* ══${NC}"; }

# ── CSV log header ─────────────────────────────────────────────────────────────
if [ ! -f "$PROCESSING_LOG" ]; then
    echo "Timestamp,Year,ProjectSlug,SourceFile,OutputCOG,SourceCRS,TargetCRS,SizeKB_In,SizeKB_Out,COG_Verified,Status,Notes" \
         > "$PROCESSING_LOG"
fi

# ── Dependency check ──────────────────────────────────────────────────────────
log_section "CVG Backload COG Converter — Year $YEAR"
log "Source:  $INPUT_BASE"
log "Output:  $OUTPUT_BASE"
log "Log:     $LOG_FILE"
log ""

for dep in gdal_translate gdalinfo gdalwarp; do
    if ! command -v "$dep" &>/dev/null; then
        log_error "Missing dependency: $dep — install GDAL >= 3.1"
        exit 1
    fi
done
log_success "GDAL $(gdal_translate --version | head -1) — OK"

if [ ! -d "$INPUT_BASE" ]; then
    log_error "Input directory not found: $INPUT_BASE"
    log_error "Map Z:\\ or copy data to NAS first."
    exit 1
fi

mkdir -p "$OUTPUT_BASE"

# ── Counters ──────────────────────────────────────────────────────────────────
COUNT_TOTAL=0; COUNT_OK=0; COUNT_SKIP=0; COUNT_ERROR=0

# ── COG conversion function ───────────────────────────────────────────────────

convert_to_cog() {
    local INPUT_FILE="$1"
    local PROJECT_SLUG="$2"   # e.g. seebeck_wd, gfelix, fdot
    local LAYER_NAME="$3"     # e.g. wetland_seebeck_wd_2025_dem

    local OUT_DIR="${OUTPUT_BASE}/${PROJECT_SLUG}"
    local OUT_FILE="${OUT_DIR}/${LAYER_NAME}_cog.tif"
    local SIZE_IN; SIZE_IN=$(du -k "$INPUT_FILE" | cut -f1)

    COUNT_TOTAL=$((COUNT_TOTAL + 1))
    log ""
    log_section "Processing: $(basename "$INPUT_FILE")"
    log "  Source:  $INPUT_FILE"
    log "  Output:  $OUT_FILE"

    # Check if already a COG
    if [ -f "$OUT_FILE" ]; then
        log_warn "  Already exists — skipping (delete to force reconvert): $OUT_FILE"
        COUNT_SKIP=$((COUNT_SKIP + 1))
        echo "$(date '+%Y-%m-%d %H:%M:%S'),$YEAR,$PROJECT_SLUG,$INPUT_FILE,$OUT_FILE,,,,$SIZE_IN,,skipped,already_exists" \
             >> "$PROCESSING_LOG"
        return 0
    fi

    mkdir -p "$OUT_DIR"

    # ── Step 1: Get source CRS ─────────────────────────────────────────────────
    local SRC_CRS
    SRC_CRS=$(gdalinfo "$INPUT_FILE" 2>/dev/null | grep -E "EPSG|ID\[" | head -1 || echo "unknown")
    log "  Source CRS: $SRC_CRS"

    # ── Step 2: Determine if reprojection needed ───────────────────────────────
    local NEEDS_WARP=false
    if echo "$SRC_CRS" | grep -qvE "4326|WGS.84"; then
        # Check more thoroughly with gdalinfo
        if ! gdalinfo "$INPUT_FILE" 2>/dev/null | grep -qE "GEOGCS\[.WGS 84|EPSG.*4326"; then
            NEEDS_WARP=true
            log_warn "  CRS is NOT EPSG:4326 — will reproject during COG conversion"
        fi
    fi

    # ── Step 3: Convert to COG ────────────────────────────────────────────────
    local STATUS="ok"
    if $NEEDS_WARP; then
        # Reproject + COG
        log "  Running: gdalwarp (reproject to $TARGET_CRS) + COG output..."
        if gdalwarp \
            -t_srs "$TARGET_CRS" \
            -of COG \
            -co COMPRESS=DEFLATE \
            -co PREDICTOR=2 \
            -co RESAMPLING=NEAREST \
            -co OVERVIEWS=AUTO \
            "$INPUT_FILE" "$OUT_FILE" >> "$LOG_FILE" 2>&1; then
            log_success "  Reprojected + COG conversion OK"
        else
            log_error "  gdalwarp failed for: $INPUT_FILE"
            STATUS="error_warp"; COUNT_ERROR=$((COUNT_ERROR + 1))
        fi
    else
        # Direct COG conversion
        log "  Running: gdal_translate → COG (no reprojection needed)..."
        if gdal_translate \
            -of COG \
            -co COMPRESS=DEFLATE \
            -co PREDICTOR=2 \
            -co OVERVIEWS=IGNORE_EXISTING \
            -co RESAMPLING=NEAREST \
            "$INPUT_FILE" "$OUT_FILE" >> "$LOG_FILE" 2>&1; then
            log_success "  COG conversion OK"
        else
            log_error "  gdal_translate failed for: $INPUT_FILE"
            STATUS="error_translate"; COUNT_ERROR=$((COUNT_ERROR + 1))
        fi
    fi

    # ── Step 4: Verify COG ────────────────────────────────────────────────────
    if [ -f "$OUT_FILE" ]; then
        local COG_CHECK; COG_CHECK=$(gdalinfo "$OUT_FILE" 2>/dev/null | grep -c "LAYOUT=COG" || echo "0")
        local SIZE_OUT; SIZE_OUT=$(du -k "$OUT_FILE" | cut -f1)

        if [ "$COG_CHECK" -gt 0 ]; then
            log_success "  COG verified: LAYOUT=COG confirmed (${SIZE_OUT}KB)"
            COUNT_OK=$((COUNT_OK + 1))
        else
            log_warn "  COG layout not confirmed — check gdalinfo output"
            STATUS="warn_cog_layout"
        fi

        echo "$(date '+%Y-%m-%d %H:%M:%S'),$YEAR,$PROJECT_SLUG,$(basename "$INPUT_FILE"),$(basename "$OUT_FILE"),$SRC_CRS,$TARGET_CRS,$SIZE_IN,$SIZE_OUT,$COG_CHECK,$STATUS," \
             >> "$PROCESSING_LOG"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S'),$YEAR,$PROJECT_SLUG,$(basename "$INPUT_FILE"),,,$SRC_CRS,$TARGET_CRS,$SIZE_IN,,0,error_no_output," \
             >> "$PROCESSING_LOG"
    fi
}

# ── Main: Walk input directory tree ───────────────────────────────────────────

log_section "Scanning $INPUT_BASE for raster files"

while IFS= read -r -d '' RASTER_FILE; do
    EXT="${RASTER_FILE##*.}"
    EXT_LOWER="${EXT,,}"

    # Check extension
    VALID=false
    for valid_ext in $RASTER_EXTENSIONS; do
        if [ "$EXT_LOWER" = "$valid_ext" ]; then VALID=true; break; fi
    done
    $VALID || continue

    # Skip sidecar files
    [[ "$RASTER_FILE" == *".ovr" ]] && continue
    [[ "$RASTER_FILE" == *".aux.xml" ]] && continue

    # Derive project slug from parent folder name
    # Pattern: NAS staging layout:  /mnt/cgps/backload/2026/{projectSlug}/...
    #          Z:\ layout:          Z:/2026/{YY##_ClientName}/...
    REL_PATH="${RASTER_FILE#${INPUT_BASE}/}"
    PROJECT_SLUG=$(echo "$REL_PATH" | cut -d'/' -f1 | \
        sed 's/^[0-9]*[_ ]//g' | \
        tr '[:upper:]' '[:lower:]' | \
        sed 's/[^a-z0-9]/_/g' | \
        sed 's/__*/_/g' | \
        sed 's/^_//;s/_$//')

    # Derive layer name from file name (strip extension, lowercase)
    FILE_BASENAME=$(basename "$RASTER_FILE" ".$EXT")
    LAYER_NAME=$(echo "${PROJECT_SLUG}_${FILE_BASENAME}" | \
        tr '[:upper:]' '[:lower:]' | \
        sed 's/[^a-z0-9_]/_/g' | \
        sed 's/__*/_/g')

    convert_to_cog "$RASTER_FILE" "$PROJECT_SLUG" "$LAYER_NAME"

done < <(find "$INPUT_BASE" -type f \( \
    -iname "*.tif" -o -iname "*.tiff" -o \
    -iname "*.img" -o -iname "*.dem"  -o \
    -iname "*.asc" -o -iname "*.grd"  -o \
    -iname "*.flt" -o -iname "*.hgt"  -o \
    -iname "*.nc"  -o -iname "*.vrt"  -o \
    -iname "*.sid" -o -iname "*.ecw"  -o \
    -iname "*.jp2" -o -iname "*.mrf" \
\) -print0)

# ── Final Summary ─────────────────────────────────────────────────────────────
log ""
log_section "COG CONVERSION COMPLETE — Z:\\$YEAR"
log "  Total processed: $COUNT_TOTAL"
log_success "  Successful:      $COUNT_OK"
log_warn    "  Skipped:         $COUNT_SKIP"
log_error   "  Errors:          $COUNT_ERROR"
log ""
log "  Processing log: $PROCESSING_LOG"
log "  Detailed log:   $LOG_FILE"
log ""
if [ "$COUNT_ERROR" -gt 0 ]; then
    log_warn "  Review errors above and in $LOG_FILE before publishing to GeoServer."
fi
log_success "  ✓ Ready for Phase 4: backload_publish_raster.sh $YEAR"
log ""
