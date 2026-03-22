#!/bin/bash
# =============================================================================
# CVG GeoServer — Backload COG Conversion Script
# Converts raw rasters from /mnt/cgps/{year}/{project}/ to COG in /mnt/cgdp/backload/
# Run on VM 454 HOST (where /mnt/cgdp is writable) after installing gdal-bin
# Usage:  bash backload_cog_convert.sh [YEAR] [PROJECT_DIR (optional)]
# Example: bash backload_cog_convert.sh 2024
#          bash backload_cog_convert.sh 2024 "2413 CMurphy"
# (c) Clearview Geographic LLC — All Rights Reserved
# =============================================================================

set -euo pipefail

YEAR="${1:-2024}"
PROJECT_FILTER="${2:-}"  # optional: only convert this project subfolder
CGPS="/mnt/cgps"
CGDP="/mnt/cgdp/backload"
LOG="/tmp/cog_convert_${YEAR}.log"
COUNT_OK=0
COUNT_SKIP=0
COUNT_ERR=0

echo "================================================================="
echo " CVG Backload COG Conversion"
echo " Year: $YEAR | Source: $CGPS/$YEAR | Output: $CGDP/$YEAR"
echo " Started: $(date)"
echo "================================================================="
echo ""

# Supported raster extensions
EXTS=( "*.tif" "*.tiff" "*.img" "*.dem" "*.asc" "*.grd" "*.ecw" "*.jp2" "*.sid" "*.flt" )

if [ ! -d "$CGPS/$YEAR" ]; then
    echo "ERROR: Source directory $CGPS/$YEAR not found — is CGPS mounted at $CGPS?"
    exit 1
fi

mkdir -p "$CGDP/$YEAR"

process_raster() {
    local SRC="$1"
    local RELPATH="${SRC#$CGPS/$YEAR/}"
    local PROJ=$(echo "$RELPATH" | cut -d'/' -f1)
    local FILENAME=$(basename "$SRC")
    local BASENAME="${FILENAME%.*}"
    local OUTDIR="$CGDP/$YEAR/${PROJ}"
    local OUT="$OUTDIR/${BASENAME}_cog.tif"

    # Skip if already converted
    if [ -f "$OUT" ]; then
        echo "  SKIP (exists): $OUT"
        COUNT_SKIP=$((COUNT_SKIP + 1))
        return
    fi

    mkdir -p "$OUTDIR"

    echo "  COG: $SRC"
    echo "    -> $OUT"

    # Get source CRS — reproject to EPSG:4326 if not already geographic
    local SIZE_X
    SIZE_X=$(gdalinfo "$SRC" 2>/dev/null | grep "^Size is" | awk '{print $3}' | tr -d ',')

    # Skip tiny files (thumbnails, world files, etc.)
    if [ -n "$SIZE_X" ] && [ "$SIZE_X" -lt 10 ] 2>/dev/null; then
        echo "  SKIP (too small: ${SIZE_X}px): $SRC"
        COUNT_SKIP=$((COUNT_SKIP + 1))
        return
    fi

    # COG conversion with reprojection to EPSG:4326
    if gdalwarp \
        -t_srs EPSG:4326 \
        -r bilinear \
        -of COG \
        -co COMPRESS=DEFLATE \
        -co PREDICTOR=2 \
        -co BIGTIFF=IF_SAFER \
        -co OVERVIEW_RESAMPLING=BILINEAR \
        -co NUM_THREADS=ALL_CPUS \
        -co BLOCKSIZE=512 \
        -dstnodata -9999 \
        "$SRC" "$OUT" 2>> "$LOG"; then
        echo "  ✅ OK: $OUT"
        COUNT_OK=$((COUNT_OK + 1))
        echo "$(date)|OK|$SRC|$OUT" >> "$LOG"
    else
        echo "  ❌ ERROR: $SRC (check $LOG)"
        COUNT_ERR=$((COUNT_ERR + 1))
        echo "$(date)|ERROR|$SRC" >> "$LOG"
        rm -f "$OUT"  # remove partial output
    fi
}

# Build find args from extension list
FIND_NAME_ARGS=()
for ext in "${EXTS[@]}"; do
    FIND_NAME_ARGS+=(-iname "$ext" -o)
done
unset 'FIND_NAME_ARGS[-1]'  # remove trailing -o

SEARCH_PATH="$CGPS/$YEAR"
if [ -n "$PROJECT_FILTER" ]; then
    SEARCH_PATH="$CGPS/$YEAR/$PROJECT_FILTER"
    echo "Filtering to project: $PROJECT_FILTER"
fi

echo "Scanning $SEARCH_PATH for rasters..."
echo ""

while IFS= read -r -d $'\0' f; do
    process_raster "$f"
done < <(find "$SEARCH_PATH" -type f \( "${FIND_NAME_ARGS[@]}" \) -print0 2>/dev/null)

echo ""
echo "================================================================="
echo " COG Conversion Complete"
echo " Year: $YEAR | ✅ OK: $COUNT_OK | ⏭ Skipped: $COUNT_SKIP | ❌ Errors: $COUNT_ERR"
echo " Log: $LOG"
echo " Output: $CGDP/$YEAR/"
echo " Finished: $(date)"
echo "================================================================="
