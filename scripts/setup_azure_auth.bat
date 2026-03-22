@echo off
REM ============================================================
REM  CVG GeoServer — Azure One-Time Auth Setup
REM  Run this ONCE on each new Windows machine.
REM  After this, all scripts use your identity — no passwords.
REM ============================================================
SETLOCAL EnableDelayedExpansion

echo.
echo ============================================================
echo  CVG GeoServer - Azure Passwordless Auth Setup
echo ============================================================
echo.

REM ── Configuration — edit these before running ────────────────
SET RESOURCE_GROUP=cvg-rg
SET LOCATION=eastus
SET KEYVAULT_NAME=cvg-keyvault
SET ACR_NAME=cvgregistry
REM ─────────────────────────────────────────────────────────────

REM Step 1: Check az CLI is installed
echo [1/6] Checking Azure CLI...
az --version >nul 2>&1
IF ERRORLEVEL 1 (
    echo    Azure CLI not found. Installing via winget...
    winget install Microsoft.AzureCLI
    IF ERRORLEVEL 1 (
        echo    ERROR: Could not install Azure CLI.
        echo    Download manually: https://aka.ms/installazurecliwindows
        pause
        exit /b 1
    )
)
echo    Azure CLI found. OK.
echo.

REM Step 2: Login (browser opens — sign in with your Azure AD account)
echo [2/6] Logging in to Azure...
echo    A browser window will open. Sign in with your Azure AD account.
echo.
az login
IF ERRORLEVEL 1 (
    echo    ERROR: Login failed.
    pause
    exit /b 1
)
echo.

REM Step 3: Show available subscriptions and set default
echo [3/6] Azure Subscriptions available:
az account list --query "[].{Name:name, ID:id, State:state}" -o table
echo.
SET /P SUBSCRIPTION_ID="Enter your Subscription ID or Name to use (copy from above): "
az account set --subscription "!SUBSCRIPTION_ID!"
IF ERRORLEVEL 1 (
    echo    ERROR: Could not set subscription. Check the ID or name above.
    pause
    exit /b 1
)
echo    Default subscription set. OK.
echo.

REM Step 4: Create Resource Group (if it doesn't exist)
echo [4/6] Ensuring Resource Group exists: %RESOURCE_GROUP%
az group create --name %RESOURCE_GROUP% --location %LOCATION% --output none
echo    Resource Group ready. OK.
echo.

REM Step 5: Create Key Vault (if it doesn't exist)
echo [5/6] Ensuring Azure Key Vault exists: %KEYVAULT_NAME%
az keyvault show --name %KEYVAULT_NAME% --resource-group %RESOURCE_GROUP% >nul 2>&1
IF ERRORLEVEL 1 (
    echo    Creating Key Vault %KEYVAULT_NAME%...
    az keyvault create ^
        --name %KEYVAULT_NAME% ^
        --resource-group %RESOURCE_GROUP% ^
        --location %LOCATION% ^
        --enable-rbac-authorization false ^
        --output none
    IF ERRORLEVEL 1 (
        echo    WARNING: Key Vault creation failed. Name may already exist globally.
        echo    Try a different name in the config at the top of this script.
    ) ELSE (
        echo    Key Vault created. OK.
    )
) ELSE (
    echo    Key Vault already exists. OK.
)
echo.

REM Step 6: Verify identity and show summary
echo [6/6] Verifying your Azure identity...
echo.
az account show --query "{Account:user.name, Subscription:name, TenantID:tenantId}" -o table
echo.

echo ============================================================
echo  Setup Complete!
echo ============================================================
echo.
echo  What was configured:
echo    - Logged in as YOUR Azure AD identity (no passwords)
echo    - Default subscription set
echo    - Resource Group: %RESOURCE_GROUP%
echo    - Key Vault: %KEYVAULT_NAME%
echo.
echo  Next steps:
echo    1. Store your GeoServer passwords in Key Vault:
echo.
echo       az keyvault secret set --vault-name %KEYVAULT_NAME% ^
echo           --name geoserver-admin-password --value "yourpassword"
echo.
echo       az keyvault secret set --vault-name %KEYVAULT_NAME% ^
echo           --name nas-cifs-password --value "yourpassword"
echo.
echo    2. Run deploy_azure.sh to deploy without any passwords.
echo.
echo    3. When you create Azure VMs, run:
echo       scripts\setup_vm_managed_identity.bat ^<vm-name^>
echo.
echo  Token caching: Your az login token is cached at %%USERPROFILE%%\.azure\
echo  Re-login needed: Only when token expires (typically every 60-90 days)
echo.
pause
ENDLOCAL
