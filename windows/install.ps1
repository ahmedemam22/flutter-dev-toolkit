# install.ps1 — one-shot installer for Flutter PowerShell helpers on Windows
# Run from this folder in PowerShell:
#   .\install.ps1
#
# If you get a script execution policy error, run once:
#   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Source    = Join-Path $ScriptDir 'flutter.ps1'
$Target    = $PROFILE

Write-Host "▶ Installing Flutter PowerShell helpers..." -ForegroundColor Blue

# 1. Ensure $PROFILE exists
if (-not (Test-Path $Target)) {
    New-Item -ItemType File -Path $Target -Force | Out-Null
    Write-Host "  • Created $Target"
}

# 2. Build the line we'll add
$SourceLine = ". `"$Source`""

# 3. Check if profile already dot-sources our script
$existing = Get-Content $Target -ErrorAction SilentlyContinue
if ($existing -and ($existing -join "`n").Contains($Source)) {
    Write-Host "  • \$PROFILE already sources flutter.ps1 — skipping"
} else {
    Add-Content -Path $Target -Value ""
    Add-Content -Path $Target -Value "# Flutter workflow helpers"
    Add-Content -Path $Target -Value $SourceLine
    Write-Host "  • Added source line to \$PROFILE"
}

# 4. Check execution policy
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -eq 'Restricted' -or $policy -eq 'Undefined') {
    Write-Host ""
    Write-Host "[warn] Your PowerShell execution policy is '$policy'." -ForegroundColor Yellow
    Write-Host "        The helpers won't load until you allow local scripts:" -ForegroundColor Yellow
    Write-Host "        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Installed. Reload your shell:" -ForegroundColor Green
Write-Host "    . `$PROFILE"
Write-Host ""
Write-Host "Then try:  fhelp"
