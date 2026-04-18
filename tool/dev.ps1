# tool/dev.ps1 — project-local Flutter build pipelines for Windows PowerShell
# Commit this alongside tool/dev.sh so Windows teammates use the same flows.
#
# Usage from project root:
#   .\tool\dev.ps1 apk [flags]
#   .\tool\dev.ps1 aab [flags]
#   .\tool\dev.ps1 refresh
#   .\tool\dev.ps1 gen
#   .\tool\dev.ps1 watch
#   .\tool\dev.ps1 nuke

$ErrorActionPreference = 'Stop'

# cd to repo root (parent of tool/)
Set-Location (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..')

# ---------- colored logging ----------
function log  { param([string]$m) Write-Host "[dev] "  -ForegroundColor Blue   -NoNewline; Write-Host $m }
function ok   { param([string]$m) Write-Host "[ok ] "  -ForegroundColor Green  -NoNewline; Write-Host $m }
function warn { param([string]$m) Write-Host "[warn] " -ForegroundColor Yellow -NoNewline; Write-Host $m }
function err  { param([string]$m) Write-Host "[err] "  -ForegroundColor Red    -NoNewline; Write-Host $m }

# FVM-aware
function Get-FlutterBin {
    if ((Test-Path .fvm) -and (Get-Command fvm -ErrorAction SilentlyContinue)) {
        return @('fvm', 'flutter')
    }
    return @('flutter')
}

function Invoke-Step {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Cmd
    )
    log "▶ $Label"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    & $Cmd[0] @($Cmd[1..($Cmd.Length - 1)])
    $code = $LASTEXITCODE
    $sw.Stop()
    $secs = [math]::Round($sw.Elapsed.TotalSeconds)
    if ($code -ne 0 -and $null -ne $code) {
        err "$Label failed (exit $code)"
        exit $code
    }
    ok "$Label (${secs}s)"
}

$FL = Get-FlutterBin

function Cmd-Apk {
    Invoke-Step "flutter clean"   @FL 'clean'
    Invoke-Step "flutter pub get" @FL 'pub' 'get'
    Invoke-Step "flutter build apk $($args -join ' ')" @FL 'build' 'apk' @args
    ok "APK -> build\app\outputs\flutter-apk\"
}

function Cmd-Aab {
    Invoke-Step "flutter clean"   @FL 'clean'
    Invoke-Step "flutter pub get" @FL 'pub' 'get'
    Invoke-Step "flutter build appbundle --release $($args -join ' ')" @FL 'build' 'appbundle' '--release' @args
    ok "AAB -> build\app\outputs\bundle\"
}

function Cmd-Refresh {
    Invoke-Step "flutter clean"   @FL 'clean'
    Invoke-Step "flutter pub get" @FL 'pub' 'get'
}

function Cmd-Gen {
    Invoke-Step "flutter pub get" @FL 'pub' 'get'
    Invoke-Step "build_runner build --delete-conflicting-outputs" `
        @FL 'pub' 'run' 'build_runner' 'build' '--delete-conflicting-outputs' @args
    ok "Code generation complete"
}

function Cmd-Watch {
    log "▶ build_runner watch (Ctrl+C to stop)"
    & $FL[0] @($FL[1..($FL.Length - 1)]) 'pub' 'run' 'build_runner' 'watch' '--delete-conflicting-outputs' @args
}

function Cmd-Nuke {
    warn "Wiping .dart_tool, build\, .flutter-plugins*"
    Invoke-Step "flutter clean" @FL 'clean'
    if (Test-Path build)       { Remove-Item -Recurse -Force build }
    if (Test-Path .dart_tool)  { Remove-Item -Recurse -Force .dart_tool }
    Get-ChildItem -File -Filter '.flutter-plugins*' -Force -ErrorAction SilentlyContinue | Remove-Item -Force
    Invoke-Step "flutter pub get" @FL 'pub' 'get'
    ok "Nuke complete"
}

function Show-Usage {
@"
Usage: .\tool\dev.ps1 <command> [args...]

Commands:
  apk [flags]                    Clean + pub get + build APK
  aab [flags]                    Clean + pub get + build App Bundle (release)
  refresh                        Clean + pub get
  gen                            pub get + build_runner build --delete-conflicting-outputs
  watch                          build_runner watch --delete-conflicting-outputs
  nuke                           Full reset: .dart_tool, build/, reinstall
  help                           Show this

Note: ipa is not supported on Windows (requires macOS + Xcode).

Examples:
  .\tool\dev.ps1 apk --release --flavor prod
  .\tool\dev.ps1 aab --flavor prod -t lib/main_prod.dart
  .\tool\dev.ps1 gen
"@ | Write-Host
}

$Command = if ($args.Count -gt 0) { $args[0] } else { 'help' }
$Rest    = if ($args.Count -gt 1) { $args[1..($args.Count - 1)] } else { @() }

switch ($Command) {
    'apk'     { Cmd-Apk     @Rest }
    'aab'     { Cmd-Aab     @Rest }
    'refresh' { Cmd-Refresh @Rest }
    'gen'     { Cmd-Gen     @Rest }
    'watch'   { Cmd-Watch   @Rest }
    'nuke'    { Cmd-Nuke    @Rest }
    { $_ -in 'help', '-h', '--help' } { Show-Usage }
    default   { err "Unknown command: $Command"; Show-Usage; exit 1 }
}
