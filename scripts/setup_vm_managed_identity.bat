@echo off
REM ============================================================
REM  CVG GeoServer — Azure VM Managed Identity Setup
REM  Run ONCE per new Azure VM to wire up passwordless auth.
REM
REM  Usage: setup_vm_managed_identity.bat <vm-name>
REM  Example: setup_vm_managed_identity.bat cvg-geoserver-raster-01
REM
REM  After running this:
REM    - VM can pull images from ACR without any password
REM    - VM can read secrets from Key Vault without any password
REM    - You can SSH to the VM using: az ssh vm -g cvg-rg -n <vm-name>
REM ============================================================
SETLOCAL EnableDelayedExpansion

REM ── Configuration — edit these ────────────────────────────────
SET RESOURCE_GROUP=cvg-rg
SET KEYVAULT_NAME=cvg-keyvault-01
SET ACR_NAME=cvgregistry
SET LOCATION=eastus
REM ─────────────────────────────────────────────────────────────

REM Get VM name from argument
SET VM_NAME=%~1
IF "%VM_NAME%"=="" (
    echo.
    echo  Usage: setup_vm_managed_identity.bat ^<vm-name^>
    echo  Example: setup_vm_managed_identity.bat cvg-geoserver-raster-01
    echo.
    SET /P VM_NAME="Enter VM name: "
)

IF "%VM_NAME%"=="" (
    echo  ERROR: No VM name provided. Exiting.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  CVG GeoServer - VM Managed Identity Setup
echo  VM: %VM_NAME%  ^|  RG: %RESOURCE_GROUP%
echo ============================================================
echo.

REM ── Step 1: Verify az login ───────────────────────────────────
echo [1/6] Verifying Azure login...
az account show --query "user.name" -o tsv >nul 2>&1
IF ERRORLEVEL 1 (
    echo    Not logged in. Running az login...
    az login
)
FOR /F "tokens=*" %%A IN ('az account show --query "user.name" -o tsv') DO SET CURRENT_USER=%%A
echo    Logged in as: %CURRENT_USER%
echo.

REM ── Step 2: Enable System-Assigned Managed Identity on VM ─────
echo [2/6] Enabling System-Assigned Managed Identity on VM: %VM_NAME%...
az vm identity assign ^
    --resource-group %RESOURCE_GROUP% ^
    --name %VM_NAME% ^
    --output none
IF ERRORLEVEL 1 (
    echo    ERROR: Could not assign identity. Check VM name and resource group.
    pause
    exit /b 1
)
echo    Managed Identity enabled. OK.
echo.

REM ── Step 3: Get VM's Principal ID ─────────────────────────────
echo [3/6] Retrieving VM identity principal ID...
FOR /F "tokens=*" %%A IN ('az vm show --resource-group %RESOURCE_GROUP% --name %VM_NAME% --query identity.principalId -o tsv') DO SET PRINCIPAL_ID=%%A
IF "%PRINCIPAL_ID%"=="" (
    echo    ERROR: Could not retrieve Principal ID. Wait 30 seconds and retry.
    pause
    exit /b 1
)
echo    Principal ID: %PRINCIPAL_ID%
echo.

REM ── Step 4: Grant VM identity AcrPull on ACR ──────────────────
echo [4/6] Granting VM identity AcrPull on ACR: %ACR_NAME%...
FOR /F "tokens=*" %%A IN ('az acr show --name %ACR_NAME% --query id -o tsv 2^>nul') DO SET ACR_ID=%%A
IF "%ACR_ID%"=="" (
    echo    ACR '%ACR_NAME%' not found — skipping ACR role assignment.
    echo    Create ACR first with: az acr create --name %ACR_NAME% --resource-group %RESOURCE_GROUP% --sku Basic
) ELSE (
    az role assignment create ^
        --assignee %PRINCIPAL_ID% ^
        --role AcrPull ^
        --scope %ACR_ID% ^
        --output none
    echo    AcrPull role granted. OK.
)
echo.

REM ── Step 5: Grant VM identity read on Key Vault ───────────────
echo [5/6] Granting VM identity read access on Key Vault: %KEYVAULT_NAME%...
az keyvault show --name %KEYVAULT_NAME% >nul 2>&1
IF ERRORLEVEL 1 (
    echo    Key Vault '%KEYVAULT_NAME%' not found — skipping.
    echo    Run setup_azure_auth.bat first to create Key Vault.
) ELSE (
    az keyvault set-policy ^
        --name %KEYVAULT_NAME% ^
        --object-id %PRINCIPAL_ID% ^
        --secret-permissions get list ^
        --output none
    echo    Key Vault read policy granted. OK.
)
echo.

REM ── Step 6: Enable Azure AD SSH login on VM ───────────────────
echo [6/6] Enabling Azure AD SSH login on VM...
az extension add --name ssh --only-show-errors >nul 2>&1

az vm extension set ^
    --resource-group %RESOURCE_GROUP% ^
    --vm-name %VM_NAME% ^
    --name AADSSHLoginForLinux ^
    --publisher Microsoft.Azure.ActiveDirectory ^
    --output none
IF ERRORLEVEL 1 (
    echo    WARNING: AAD SSH extension install failed — may not be supported on this VM image.
    echo    Falling back to SSH key auth (still no passwords).
) ELSE (
    REM Grant current user VM Administrator Login role
    FOR /F "tokens=*" %%A IN ('az ad user show --id %CURRENT_USER% --query id -o tsv 2^>nul') DO SET USER_OBJECT_ID=%%A
    IF NOT "%USER_OBJECT_ID%"=="" (
        FOR /F "tokens=*" %%A IN ('az vm show --resource-group %RESOURCE_GROUP% --name %VM_NAME% --query id -o tsv') DO SET VM_ID=%%A
        az role assignment create ^
            --assignee %USER_OBJECT_ID% ^
            --role "Virtual Machine Administrator Login" ^
            --scope %VM_ID% ^
            --output none 2>nul
        echo    Azure AD SSH enabled. OK.
    ) ELSE (
        echo    Azure AD SSH extension installed.
        echo    Grant yourself access manually:
        echo      az role assignment create --assignee your-email@domain.com --role "Virtual Machine Administrator Login" --resource-group %RESOURCE_GROUP%
    )
)
echo.

echo ============================================================
echo  VM Managed Identity Setup Complete!
echo ============================================================
echo.
echo  VM '%VM_NAME%' now has:
echo    - System-Assigned Managed Identity: %PRINCIPAL_ID%
echo    - AcrPull access to: %ACR_NAME%
echo    - Key Vault read access to: %KEYVAULT_NAME%
echo    - Azure AD SSH login enabled
echo.
echo  SSH to VM (no password — uses your az login token):
echo    az ssh vm --resource-group %RESOURCE_GROUP% --name %VM_NAME%
echo.
echo  On the VM, Docker can pull from ACR with no credentials:
echo    az acr login --name %ACR_NAME%
echo    docker pull %ACR_NAME%.azurecr.io/geoserver-raster:latest
echo.
echo  On the VM, scripts can read Key Vault secrets:
echo    az keyvault secret show --vault-name %KEYVAULT_NAME% --name geoserver-admin-password --query value -o tsv
echo.
pause
ENDLOCAL
