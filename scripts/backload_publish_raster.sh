#!/bin/bash
# =============================================================================
# CVG GeoServer — Backload Raster Layer Publisher
# Registers COG GeoTIFF files from /mnt/cgdp/backload/ in GeoServer via REST API
# Run on VM 454 HOST after running backload_cog_convert.sh
# Usage:  bash backload_publish_raster.sh [YEAR] [PROJECT (optional)]
# Example: bash backload_publish_raster.sh 2024
#          bash backload_publish_raster.sh 2024 "2413_CMurphy"
# (c) Clearview Geographic LLC — All Rights Reserved
# =============================================================================

set -euo pipefail

YEAR="${1:-2024}"
PROJECT_FILTER="${2:-}"
GS_URL="http://localhost:8080/geoserver"  # internal URL via docker exec
GS_USER="admin"
GS_PASS="CVGRaster2026Secure"
WS="cvg"
CGDP="/mnt/cgdp/backload"
LOG="/tmp/backload_publish_${YEAR}.log"
COUNT_OK=0
COUNT_SKIP=0
COUNT_ERR=0

echo "================================================================="
echo " CVG Backload Raster Publisher"
echo " Year: $YEAR | GeoServer: https://raster.cleargeo.tech"
echo " Workspace: $WS | Started: $(date)"
echo "================================================================="
echo ""

# Test authentication
HTTP=$(docker exec geoserver-raster curl -s -o /dev/null -w "%{http_code}" \
    -u "$GS_USER:$GS_PASS" \
    "$GS_URL/rest/workspaces/$WS")
if [ "$HTTP" != "200" ]; then
    echo "ERROR: GeoServer auth failed (HTTP $HTTP). Check GS_PASS."
    exit 1
fi
echo "✅ GeoServer auth OK (workspace '$WS' verified)"
echo ""

gs_curl() {
    docker exec geoserver-raster curl -s -o /dev/null -w "%{http_code}" \
        -u "$GS_USER:$GS_PASS" "$@"
}

derive_layer_name() {
    local FILE="$1"
    local YR="$2"
    local PROJ="$3"
    # Format: dem_2413cmurphy_2024 / dsm_1817stetson_2018 etc.
    # Remove spaces, lowercase, strip special chars
    local PSLUG
    PSLUG=$(echo "$PROJ" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g' | sed 's/__*/_/g' | cut -c1-30)
    local FNAME
    FNAME=$(basename "$FILE" _cog.tif | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g' | cut -c1-20)
    echo "dem_${PSLUG}_${YR}"
}

publish_layer() {
    local COG_PATH="$1"     # Absolute path on VM host (/mnt/cgdp/backload/...)
    local YEAR="$2"
    local PROJ="$3"

    # Path as seen inside geoserver-raster container (/mnt/cgdp is read-only in container)
    # We need the path relative to how GeoServer sees the file
    # GeoServer uses file:// URI pointing to paths the container can reach
    # Since CGDP is :ro inside container, we rely on the store URL
    local LAYER_NAME
    LAYER_NAME=$(derive_layer_name "$COG_PATH" "$YEAR" "$PROJ")
    local STORE_NAME="$LAYER_NAME"

    # Check if store already exists
    local EXISTS
    EXISTS=$(gs_curl "$GS_URL/rest/workspaces/$WS/coveragestores/$STORE_NAME")
    if [ "$EXISTS" = "200" ]; then
        echo "  SKIP (already published): $LAYER_NAME"
        COUNT_SKIP=$((COUNT_SKIP + 1))
        return
    fi

    echo "  Publishing: $LAYER_NAME"
    echo "    Source: $COG_PATH"

    # Container sees CGDP at /mnt/cgdp (read-only bind mount)
    local CONTAINER_PATH="${COG_PATH/\/mnt\/cgdp\//file:\/\/\/mnt\/cgdp\/}"

    # Create coverage store
    local CREATE_HTTP
    CREATE_HTTP=$(docker exec geoserver-raster curl -s -o /dev/null -w "%{http_code}" \
        -u "$GS_USER:$GS_PASS" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{
          \"coverageStore\": {
            \"name\": \"$STORE_NAME\",
            \"type\": \"GeoTIFF\",
            \"url\": \"file:///mnt/cgdp/backload/$YEAR/$PROJ/$(basename "$COG_PATH")\",
            \"workspace\": {\"name\": \"$WS\"},
            \"enabled\": true
          }
        }" \
        "$GS_URL/rest/workspaces/$WS/coveragestores")

    if [ "$CREATE_HTTP" = "201" ]; then
        # Publish coverage from store
        local PUB_HTTP
        PUB_HTTP=$(docker exec geoserver-raster curl -s -o /dev/null -w "%{http_code}" \
            -u "$GS_USER:$GS_PASS" \
            -X POST \
            -H "Content-Type: application/json" \
            -d "{\"coverage\": {\"name\": \"$LAYER_NAME\", \"title\": \"CVG Backload $YR $PROJ $(basename "$COG_PATH" _cog.tif)\"}}" \
            "$GS_URL/rest/workspaces/$WS/coveragestores/$STORE_NAME/coverages")

        if [ "$PUB_HTTP" = "201" ] || [ "$PUB_HTTP" = "200" ]; then
            echo "  ✅ Published: $WS:$LAYER_NAME (HTTP $PUB_HTTP)"
            COUNT_OK=$((COUNT_OK + 1))
            echo "$(date)|OK|$WS:$LAYER_NAME|$COG_PATH" >> "$LOG"
        else
            echo "  ❌ Coverage publish failed (HTTP $PUB_HTTP): $LAYER_NAME"
            COUNT_ERR=$((COUNT_ERR + 1))
            echo "$(date)|ERROR_COVERAGE|$LAYER_NAME|HTTP:$PUB_HTTP" >> "$LOG"
        fi
    else
        echo "  ❌ Store creation failed (HTTP $CREATE_HTTP): $STORE_NAME"
        COUNT_ERR=$((COUNT_ERR + 1))
        echo "$(date)|ERROR_STORE|$STORE_NAME|HTTP:$CREATE_HTTP" >> "$LOG"
    fi
}

# Scan the backload directory for COG files
SCAN_PATH="$CGDP/$YEAR"
if [ -n "$PROJECT_FILTER" ]; then
    SCAN_PATH="$CGDP/$YEAR/$PROJECT_FILTER"
fi

if [ ! -d "$SCAN_PATH" ]; then
    echo "ERROR: $SCAN_PATH not found. Run backload_cog_convert.sh $YEAR first."
    exit 1
fi

echo "Scanning $SCAN_PATH for COG files..."
echo ""

while IFS= read -r -d $'\0' f; do
    PROJ=$(echo "${f#$CGDP/$YEAR/}" | cut -d'/' -f1)
    publish_layer "$f" "$YEAR" "$PROJ"
done < <(find "$SCAN_PATH" -name "*_cog.tif" -type f -print0 2>/dev/null)

echo ""
echo "================================================================="
echo " Publish Complete"
echo " Year: $YEAR | ✅ Published: $COUNT_OK | ⏭ Skipped: $COUNT_SKIP | ❌ Errors: $COUNT_ERR"
echo " Log: $LOG"
echo " WMS: https://raster.cleargeo.tech/geoserver/wms?SERVICE=WMS&REQUEST=GetCapabilities"
echo " Finished: $(date)"
echo "================================================================="
