# =============================================================================
# CVG GeoServer Backload -- Z:\ Inventory Script
# Author: Alex Zelenski, GISP | Clearview Geographic LLC
# Version: 1.1.0 | 2026-03-22
#
# PURPOSE:
#   Walk a Z:\ year directory, enumerate ALL geospatial files, and produce
#   CSV inventory files for the GeoServer backload campaign.
#   Covers ALL CVG project types -- not just coastal/SLR.
#
# USAGE:
#   powershell -ExecutionPolicy Bypass -File backload_inventory.ps1 -Year 2026
#   powershell -ExecutionPolicy Bypass -File backload_inventory.ps1 -Year 2025 -ZDrive "Z:"
#
# OUTPUT FILES:
#   backload_inventory_{YEAR}_all_geospatial.csv
#   backload_inventory_{YEAR}_rasters.csv
#   backload_inventory_{YEAR}_vectors.csv
#   backload_inventory_{YEAR}_gdbs.csv          <- PRIMARY CVG SOURCE
#   backload_inventory_{YEAR}_aprx.csv
#   backload_inventory_{YEAR}_summary.txt
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [ValidateRange(2018, 2030)]
    [int]$Year,

    [string]$ZDrive = "Z:",

    [string]$OutputDir = $PSScriptRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$SourceDir  = Join-Path $ZDrive "$Year"
$Timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"

$RasterExts  = @('.tif','.tiff','.img','.dem','.asc','.grd','.flt','.hgt','.nc','.vrt','.sid','.ecw','.jp2','.mrf')
$VectorExts  = @('.shp','.gpkg','.geojson','.json','.kml','.kmz','.csv','.tab','.mif','.gml','.gpx')
$ProjectExts = @('.aprx','.atbx','.lyrx','.mxd','.sde')
$AllGeoExts  = $RasterExts + $VectorExts + $ProjectExts

$OutAll     = Join-Path $OutputDir ("backload_inventory_" + $Year + "_all_geospatial.csv")
$OutRaster  = Join-Path $OutputDir ("backload_inventory_" + $Year + "_rasters.csv")
$OutVector  = Join-Path $OutputDir ("backload_inventory_" + $Year + "_vectors.csv")
$OutGDB     = Join-Path $OutputDir ("backload_inventory_" + $Year + "_gdbs.csv")
$OutAPRX    = Join-Path $OutputDir ("backload_inventory_" + $Year + "_aprx.csv")
$OutSummary = Join-Path $OutputDir ("backload_inventory_" + $Year + "_summary.txt")

Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  CVG GeoServer Backload Inventory -- Z:\$Year" -ForegroundColor Cyan
Write-Host "  Clearview Geographic LLC" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $SourceDir)) {
    Write-Error "Source directory not found: $SourceDir"
    exit 1
}

Write-Host "  Source:  $SourceDir" -ForegroundColor Yellow
Write-Host "  Output:  $OutputDir" -ForegroundColor Yellow
Write-Host ""

$AllFiles = [System.Collections.Generic.List[PSCustomObject]]::new()
$AllGDBs  = [System.Collections.Generic.List[PSCustomObject]]::new()

Write-Host "[1/5] Enumerating Z:\$Year ..." -ForegroundColor Green

$AllItems = Get-ChildItem -Path $SourceDir -Recurse -ErrorAction SilentlyContinue

foreach ($item in $AllItems) {
    if ($item.PSIsContainer -and $item.Extension -eq '.gdb') {
        $parts = ($item.FullName -split [regex]::Escape("\$Year\"))
        $projFolder = if ($parts.Count -gt 1) { ($parts[1] -split "\\")[0] } else { "unknown" }
        $AllGDBs.Add([PSCustomObject]@{
            Year          = $Year
            ProjectFolder = $projFolder
            GDB_Name      = $item.Name
            GDB_Path      = $item.FullName
            ParentFolder  = $item.DirectoryName
            LastModified  = $item.LastWriteTime.ToString("yyyy-MM-dd")
            Notes         = "Run: ogrinfo -al -so on this GDB to list feature classes"
        })
    }
    if (-not $item.PSIsContainer) {
        $ext = $item.Extension.ToLower()
        if ($AllGeoExts -contains $ext) {
            $parts = ($item.FullName -split [regex]::Escape("\$Year\"))
            $projFolder = if ($parts.Count -gt 1) { ($parts[1] -split "\\")[0] } else { "unknown" }
            $category = "other"
            if ($RasterExts  -contains $ext) { $category = "raster" }
            if ($VectorExts  -contains $ext) { $category = "vector" }
            if ($ProjectExts -contains $ext) { $category = "arcgis_project" }
            $AllFiles.Add([PSCustomObject]@{
                Year              = $Year
                ProjectFolder     = $projFolder
                FileName          = $item.Name
                Extension         = $ext
                Category          = $category
                FullPath          = $item.FullName
                SizeKB            = [math]::Round($item.Length / 1KB, 1)
                LastModified      = $item.LastWriteTime.ToString("yyyy-MM-dd")
                CVG_TypeCode      = ""
                ProjectSlug       = ""
                PublishPriority   = ""
                CRS_EPSG          = ""
                GPKG_Ready        = "no"
                GeoServerLayer    = ""
                Notes             = ""
            })
        }
    }
}

$fileCount = $AllFiles.Count
$gdbCount  = $AllGDBs.Count
Write-Host "   Files: $fileCount  |  GDBs: $gdbCount" -ForegroundColor White

# Auto-classify using folder name heuristics
Write-Host "[2/5] Auto-classifying project types ..." -ForegroundColor Green

function Get-CVGTypeCode {
    param([string]$FolderName, [string]$FileName)
    $n = ($FolderName + " " + $FileName).ToLower()
    if ($n -match "wetland|wd\b|delineat|swamp|marsh")              { return "wetland" }
    if ($n -match "tree|canopy|arborist|forest|timber")             { return "treesurvey" }
    if ($n -match "fire|wildfire|fuel|wui")                         { return "fire" }
    if ($n -match "habitat|wildlife|corridor|species|fauna")        { return "habitat" }
    if ($n -match "surge|storm|hurricane|cat[1-5]")                 { return "surge" }
    if ($n -match "slr|sea.level|inundation|tidal")                 { return "slr" }
    if ($n -match "flood|fema|dfirm|firm|bfe|sfha|nfip|crs\b")      { return "flood" }
    if ($n -match "solar|pv|irradiance|rooftop")                    { return "solar" }
    if ($n -match "drone|uav|uas|ortho|lidar|dem\b")                { return "dem_ortho" }
    if ($n -match "bathymet|ocean|aquatic|water.quality")           { return "aquatic" }
    if ($n -match "mitigation|banking|credit|mitig")                { return "mitigation" }
    if ($n -match "native|restor|vegetation|plant")                 { return "vegetation" }
    if ($n -match "coastal|beach|shoreline|erosion")                { return "coastal" }
    if ($n -match "vuln|ppberp|resilience|risk.assess")             { return "vuln" }
    if ($n -match "due.dilig|due dilig|parcel|apprais")             { return "duediligence" }
    if ($n -match "stormwater|drainage|basin|watershed|swm")        { return "stormwater" }
    if ($n -match "city|county|municipal|town|state|fdot|dot\b")    { return "municipal" }
    if ($n -match "rezoning|planning|zoning|entitl")                { return "planning" }
    if ($n -match "gps|survey|field")                               { return "gpssurvey" }
    return "unknown"
}

foreach ($file in $AllFiles) {
    $file.CVG_TypeCode = Get-CVGTypeCode -FolderName $file.ProjectFolder -FileName $file.FileName
}

Write-Host "[3/5] Splitting categories ..." -ForegroundColor Green
$RasterFiles  = @($AllFiles | Where-Object { $_.Category -eq "raster" })
$VectorFiles  = @($AllFiles | Where-Object { $_.Category -eq "vector" })
$ProjectFiles = @($AllFiles | Where-Object { $_.Category -eq "arcgis_project" })
Write-Host ("   Rasters: " + $RasterFiles.Count + "  |  Vectors: " + $VectorFiles.Count + "  |  APRX: " + $ProjectFiles.Count) -ForegroundColor White

Write-Host "[4/5] Writing CSV files ..." -ForegroundColor Green
$AllFiles    | Export-Csv -Path $OutAll    -NoTypeInformation -Encoding UTF8
$RasterFiles | Export-Csv -Path $OutRaster -NoTypeInformation -Encoding UTF8
$VectorFiles | Export-Csv -Path $OutVector -NoTypeInformation -Encoding UTF8
$AllGDBs     | Export-Csv -Path $OutGDB    -NoTypeInformation -Encoding UTF8
@($AllFiles | Where-Object { $_.Extension -eq '.aprx' }) | Export-Csv -Path $OutAPRX -NoTypeInformation -Encoding UTF8
Write-Host "   CSVs written to: $OutputDir" -ForegroundColor White

Write-Host "[5/5] Writing summary ..." -ForegroundColor Green
$ExtGroups  = $AllFiles | Group-Object Extension | Sort-Object Count -Descending
$TypeGroups = $AllFiles | Group-Object CVG_TypeCode | Sort-Object Count -Descending
$ProjGroups = $AllFiles | Group-Object ProjectFolder | Sort-Object Count -Descending

$extLines  = ($ExtGroups  | ForEach-Object { "  {0,-14} {1,5} files" -f $_.Name, $_.Count }) -join "`r`n"
$typeLines = ($TypeGroups | ForEach-Object { "  {0,-22} {1,5} files" -f $_.Name, $_.Count }) -join "`r`n"
$gdbLines  = ($AllGDBs    | ForEach-Object { "  " + $_.GDB_Path }) -join "`r`n"
$projLines = ($ProjGroups | Select-Object -First 25 | ForEach-Object { "  {0,-50} {1,5} files" -f $_.Name, $_.Count }) -join "`r`n"

$summary = @"
CVG GeoServer Backload Inventory -- Summary
Year: Z:\$Year  |  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
==========================================================================
SCOPE: ALL CVG geospatial project types -- not just SLR/storm surge

TOTALS
  Total Geospatial Files : $fileCount
  Vector Files           : $($VectorFiles.Count)
  Raster Files           : $($RasterFiles.Count)
  ArcGIS .aprx           : $($ProjectFiles.Count)
  GDB Directories        : $gdbCount   <- PRIMARY VECTOR/RASTER SOURCE

EXTENSIONS FOUND
$extLines

PROJECT TYPES (auto-classified -- verify manually)
$typeLines

TOP PROJECTS BY FILE COUNT
$projLines

GDB DIRECTORIES (run ogrinfo -al -so on each to list feature classes)
$gdbLines

NEXT STEPS
  1. For each GDB above:
       ogrinfo -al -so "Z:\$Year\{project}\Aprx\{name}.gdb"
  2. Fill in CSV: CVG_TypeCode, ProjectSlug, GeoServerLayer
  3. Run: bash backload_gpkg_convert.sh $Year
  4. Run: bash backload_cog_convert.sh $Year
  5. Run: bash backload_publish_vector.sh $Year
"@

$summary | Out-File -FilePath $OutSummary -Encoding UTF8

Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ("  COMPLETE -- Z:\" + $Year + " | " + $fileCount + " files | " + $gdbCount + " GDBs") -ForegroundColor Green
Write-Host "  IMPORTANT: Most CVG vectors are INSIDE .gdb files -- run ogrinfo!" -ForegroundColor Yellow
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host $summary
