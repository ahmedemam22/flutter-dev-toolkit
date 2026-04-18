# flutter.ps1 — Flutter workflow helpers for Windows PowerShell
# Dot-source from $PROFILE:
#   . "$env:USERPROFILE\flutter-dev-toolkit\windows\flutter.ps1"
#
# Reload after edits: `rflutter`

# ---------- logging helpers ----------
function _FlLog  { param([string]$m) Write-Host "[flutter] " -ForegroundColor Blue   -NoNewline; Write-Host $m }
function _FlOk   { param([string]$m) Write-Host "[  ok  ] " -ForegroundColor Green  -NoNewline; Write-Host $m }
function _FlWarn { param([string]$m) Write-Host "[ warn ] " -ForegroundColor Yellow -NoNewline; Write-Host $m }
function _FlErr  { param([string]$m) Write-Host "[ fail ] " -ForegroundColor Red    -NoNewline; Write-Host $m }

# ---------- Flutter project guard (walks up for pubspec.yaml) ----------
function Find-FlutterRoot {
    $dir = (Get-Location).Path
    while ($dir) {
        if (Test-Path (Join-Path $dir 'pubspec.yaml')) { return $dir }
        $parent = Split-Path $dir -Parent
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}

function _FlGuard {
    if (-not (Find-FlutterRoot)) {
        _FlErr "Not inside a Flutter project (no pubspec.yaml found)."
        return $false
    }
    return $true
}

# FVM-aware flutter invocation
function _FlBin {
    if ((Test-Path .fvm) -and (Get-Command fvm -ErrorAction SilentlyContinue)) {
        return @('fvm', 'flutter')
    }
    return @('flutter')
}

# Run a step with timing; returns $true on success
function _FlStep {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Cmd
    )
    _FlLog "▶ $Label"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    & $Cmd[0] @($Cmd[1..($Cmd.Length - 1)])
    $code = $LASTEXITCODE
    $sw.Stop()
    $secs = [math]::Round($sw.Elapsed.TotalSeconds)
    if ($code -ne 0 -and $null -ne $code) {
        _FlErr "$Label failed (exit $code)"
        return $false
    }
    _FlOk "$Label (${secs}s)"
    return $true
}

# ---------- single-step aliases ----------
function Invoke-FlutterClean    { flutter clean @args };         Set-Alias fc    Invoke-FlutterClean    -Force
function Invoke-FlutterPubGet   { flutter pub get @args };       Set-Alias fpg   Invoke-FlutterPubGet   -Force
function Invoke-FlutterPubUp    { flutter pub upgrade @args };   Set-Alias fpu   Invoke-FlutterPubUp    -Force
function Invoke-FlutterPubOut   { flutter pub outdated @args };  Set-Alias fpo   Invoke-FlutterPubOut   -Force
function Invoke-FlutterDoctor   { flutter doctor -v };           Set-Alias fdo   Invoke-FlutterDoctor   -Force
function Invoke-FlutterRun      { flutter run @args };           Set-Alias fr    Invoke-FlutterRun      -Force
function Invoke-FlutterRunRel   { flutter run --release @args }; Set-Alias frr   Invoke-FlutterRunRel   -Force
function Invoke-FlutterAnalyze  { flutter analyze @args };       Set-Alias fa    Invoke-FlutterAnalyze  -Force
function Invoke-FlutterTest     { flutter test @args };          Set-Alias ft    Invoke-FlutterTest     -Force
function Invoke-FlutterDevices  { flutter devices };             Set-Alias fdev  Invoke-FlutterDevices  -Force

# ---------- compound builds ----------

# Usage: fbapk                  → debug APK
#        fbapk --release        → release APK
#        fbapk --release --flavor prod -t lib/main_prod.dart
function Build-FlutterApk {
    if (-not (_FlGuard)) { return }
    $FL = _FlBin
    if (-not (_FlStep "flutter clean"    @FL 'clean'))          { return }
    if (-not (_FlStep "flutter pub get"  @FL 'pub' 'get'))      { return }
    if (-not (_FlStep "flutter build apk $args" @FL 'build' 'apk' @args)) { return }
    _FlOk "APK pipeline complete → build\app\outputs\flutter-apk\"
}
Set-Alias fbapk Build-FlutterApk -Force

# Usage: fbaab --release --flavor prod -t lib/main_prod.dart
function Build-FlutterAab {
    if (-not (_FlGuard)) { return }
    $FL = _FlBin
    if (-not (_FlStep "flutter clean"    @FL 'clean'))         { return }
    if (-not (_FlStep "flutter pub get"  @FL 'pub' 'get'))     { return }
    if (-not (_FlStep "flutter build appbundle --release $args" @FL 'build' 'appbundle' '--release' @args)) { return }
    _FlOk "AAB pipeline complete → build\app\outputs\bundle\"
}
Set-Alias fbaab Build-FlutterAab -Force

# NOTE: iOS IPA builds require macOS + Xcode. fbipa is macOS-only.
# On Windows we expose a stub that explains this.
function Build-FlutterIpa {
    _FlErr "Building IPAs requires macOS with Xcode. This command isn't available on Windows."
    _FlWarn "Use a Mac for iOS archives, or use Codemagic / GitHub Actions macOS runners for CI."
}
Set-Alias fbipa Build-FlutterIpa -Force

# Quick clean + pub get (no build)
function Invoke-FlutterRefresh {
    if (-not (_FlGuard)) { return }
    $FL = _FlBin
    if (-not (_FlStep "flutter clean"   @FL 'clean'))     { return }
    if (-not (_FlStep "flutter pub get" @FL 'pub' 'get')) { return }
    _FlOk "Project refreshed"
}
Set-Alias frefresh Invoke-FlutterRefresh -Force
Set-Alias fcp      Invoke-FlutterRefresh -Force

# Nuke caches + reinstall (Windows version — no iOS/Pods)
function Invoke-FlutterNuke {
    if (-not (_FlGuard)) { return }
    $FL = _FlBin
    _FlWarn "Nuking: .dart_tool, build\, .flutter-plugins*"
    if (-not (_FlStep "flutter clean" @FL 'clean')) { return }
    if (Test-Path build)                  { Remove-Item -Recurse -Force build }
    if (Test-Path .dart_tool)             { Remove-Item -Recurse -Force .dart_tool }
    Get-ChildItem -File -Filter '.flutter-plugins*' -Force -ErrorAction SilentlyContinue | Remove-Item -Force
    if (-not (_FlStep "flutter pub get" @FL 'pub' 'get')) { return }
    _FlOk "Nuke complete"
}
Set-Alias fnuke Invoke-FlutterNuke -Force

# ---------- build_runner (code generation) ----------
function Invoke-BuildRunner {
    if (-not (_FlGuard)) { return }
    $FL = _FlBin
    if (-not (_FlStep "build_runner build --delete-conflicting-outputs" `
        @FL 'pub' 'run' 'build_runner' 'build' '--delete-conflicting-outputs' @args)) { return }
    _FlOk "Code generation complete"
}
Set-Alias fbr Invoke-BuildRunner -Force

function Invoke-BuildRunnerWatch {
    if (-not (_FlGuard)) { return }
    $FL = _FlBin
    _FlLog "▶ build_runner watch (Ctrl+C to stop)"
    & $FL[0] @($FL[1..($FL.Length - 1)]) 'pub' 'run' 'build_runner' 'watch' '--delete-conflicting-outputs' @args
}
Set-Alias fbrw Invoke-BuildRunnerWatch -Force

function Invoke-BuildRunnerClean {
    if (-not (_FlGuard)) { return }
    $FL = _FlBin
    if (-not (_FlStep "build_runner clean" @FL 'pub' 'run' 'build_runner' 'clean')) { return }
    _FlOk "build_runner cache cleared"
}
Set-Alias fbrc Invoke-BuildRunnerClean -Force

# pub get + build_runner build
function Invoke-FlutterGen {
    if (-not (_FlGuard)) { return }
    $FL = _FlBin
    if (-not (_FlStep "flutter pub get" @FL 'pub' 'get')) { return }
    if (-not (_FlStep "build_runner build --delete-conflicting-outputs" `
        @FL 'pub' 'run' 'build_runner' 'build' '--delete-conflicting-outputs' @args)) { return }
    _FlOk "Regen complete"
}
Set-Alias fgen Invoke-FlutterGen -Force

# ---------- utilities ----------

# Open build artifact folder in Explorer
function Open-FlutterArtifact {
    param([Parameter(Mandatory)][ValidateSet('apk','aab')][string]$Kind)
    switch ($Kind) {
        'apk' { explorer .\build\app\outputs\flutter-apk\ }
        'aab' { explorer .\build\app\outputs\bundle\ }
    }
}
Set-Alias fopen Open-FlutterArtifact -Force

# Environment sanity check
function Show-FlutterInfo {
    _FlLog "flutter path: $((Get-Command flutter -ErrorAction SilentlyContinue).Source ?? 'not found')"
    _FlLog "flutter --version:"
    flutter --version 2>$null
    _FlLog "dart path: $((Get-Command dart -ErrorAction SilentlyContinue).Source ?? 'not found')"
}
Set-Alias finfo Show-FlutterInfo -Force

# Reload this file after edits
function Invoke-FlutterReload {
    $path = (Get-Variable FLUTTER_PS1_PATH -Scope Global -ErrorAction SilentlyContinue).Value
    if (-not $path) { $path = $PSCommandPath }
    . $path
    _FlOk "flutter helpers reloaded"
}
Set-Alias rflutter Invoke-FlutterReload -Force

# Cheat sheet
function Show-FlutterHelp {
@"
Flutter helpers:
  fc         flutter clean
  fpg        flutter pub get
  fpu        flutter pub upgrade
  fpo        flutter pub outdated
  fa         flutter analyze
  ft         flutter test
  fr / frr   flutter run / --release
  fdo        flutter doctor -v
  fdev       flutter devices

Build pipelines (clean -> pub get -> build):
  fbapk [flags]                     debug/release APK
  fbaab [flags]                     release App Bundle
  fbipa                             NOT AVAILABLE ON WINDOWS (requires macOS + Xcode)

Code generation (freezed, json, injectable, etc.):
  fbr        build_runner build --delete-conflicting-outputs
  fbrw       build_runner watch
  fbrc       build_runner clean
  fgen       pub get + build_runner build

Utilities:
  fcp / frefresh   clean + pub get
  fnuke            wipe .dart_tool + build + reinstall
  fopen apk|aab    open artifact folder in Explorer
  finfo            environment sanity check
  rflutter         reload this config
  fhelp            show this
"@ | Write-Host
}
Set-Alias fhelp Show-FlutterHelp -Force

# Remember path so rflutter can find this file
$Global:FLUTTER_PS1_PATH = $PSCommandPath
