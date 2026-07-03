<#
Builds the standalone WildCatServer.exe (Windows).

Run from the backend/ folder with the virtualenv present:
    .\build_server.ps1

Output: dist\WildCatServer.exe  (single file, no Python needed to run it).

NOTE: the exe embeds firebase_service_account.json (a real secret). Only share
the exe with trusted people, and never commit dist\ to git.
#>

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$pyinstaller = Join-Path $PSScriptRoot 'venv\Scripts\pyinstaller.exe'
if (-not (Test-Path $pyinstaller)) {
    Write-Error "pyinstaller not found. Run: .\venv\Scripts\pip install -r requirements.txt"
    exit 1
}

& $pyinstaller --noconfirm --onefile --name WildCatServer `
    --collect-all django `
    --collect-all rest_framework `
    --collect-all rest_framework_simplejwt `
    --collect-all corsheaders `
    --collect-all firebase_admin `
    --collect-all google `
    --collect-all zeroconf `
    --collect-all whitenoise `
    --collect-submodules users `
    --collect-submodules sightings `
    --collect-submodules notifications `
    --collect-submodules discovery `
    --collect-submodules core `
    --add-data "firebase_service_account.json;." `
    --hidden-import waitress `
    standalone_server.py

Write-Host ""
Write-Host "Build complete: dist\WildCatServer.exe" -ForegroundColor Green
