@echo off
REM Force Git Bash (MSYS2) — clear WSL interop env so WSL doesn't intercept bash
SET WSLENV=
SET WSL_DISTRO_NAME=
SET WSL_INTEROP=
"C:\Program Files\Git\bin\bash.exe" "G:/07_APPLICATIONS_TOOLS/CVG_Geoserver_Raster/deploy_production.sh" %*
