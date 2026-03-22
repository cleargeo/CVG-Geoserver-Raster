#!/bin/bash
# CVG GeoServer — Z:\ Project Archive Inventory Script
# Runs on VM 454 via /mnt/cgps (same data as Z:\ on workstation)
# (c) Clearview Geographic LLC

echo "=== CVG GeoServer Backload Inventory ==="
echo "=== NAS Path: /mnt/cgps | Date: $(date) ==="
echo ""

for yr in 2018 2019 2020 2021 2022 2023 2024 2025 2026; do
    BASEPATH="/mnt/cgps/$yr"
    if [ -d "$BASEPATH" ]; then
        RASTERS=$(find "$BASEPATH" -type f \( \
            -iname "*.tif" -o -iname "*.tiff" -o -iname "*.img" -o \
            -iname "*.dem" -o -iname "*.asc" -o -iname "*.grd" -o \
            -iname "*.ecw" -o -iname "*.sid" -o -iname "*.jp2" -o \
            -iname "*.flt" -o -iname "*.hdr" \) 2>/dev/null | wc -l)
        VECTORS=$(find "$BASEPATH" -type f \( \
            -iname "*.shp" -o -iname "*.gpkg" -o -iname "*.geojson" -o \
            -iname "*.kml" -o -iname "*.gml" \) 2>/dev/null | wc -l)
        GDBS=$(find "$BASEPATH" -type d -iname "*.gdb" 2>/dev/null | wc -l)
        TOTAL=$(find "$BASEPATH" -type f 2>/dev/null | wc -l)
        DIRS=$(ls "$BASEPATH" 2>/dev/null | wc -l)
        echo "Z:\\$yr | Projects:$DIRS | TotalFiles:$TOTAL | Rasters:$RASTERS | Vectors:$VECTORS | GDBs:$GDBS"

        # List project folders
        for proj in "$BASEPATH"/*/; do
            if [ -d "$proj" ]; then
                PNAME=$(basename "$proj")
                PFILES=$(find "$proj" -type f 2>/dev/null | wc -l)
                PRAS=$(find "$proj" -type f \( -iname "*.tif" -o -iname "*.tiff" -o -iname "*.img" -o -iname "*.dem" \) 2>/dev/null | wc -l)
                PVEC=$(find "$proj" -type f \( -iname "*.shp" -o -iname "*.gpkg" -o -iname "*.geojson" \) 2>/dev/null | wc -l)
                if [ "$PFILES" -gt 0 ]; then
                    echo "  -> $PNAME | Files:$PFILES | Rasters:$PRAS | Vectors:$PVEC"
                fi
            fi
        done
    else
        echo "Z:\\$yr | NOT FOUND on NAS"
    fi
    echo ""
done

echo "=== Inventory Complete ==="
