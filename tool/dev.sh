#!/usr/bin/env bash
# tool/dev.sh — project-local Flutter build pipelines
# Works on macOS & Linux. Safe to commit to the repo.
#
# Usage from project root:
#   ./tool/dev.sh apk [flutter-build-flags...]
#   ./tool/dev.sh ipa [entrypoint] [flutter-build-flags...]
#   ./tool/dev.sh aab [flutter-build-flags...]
#   ./tool/dev.sh refresh
#   ./tool/dev.sh nuke

set -euo pipefail

# cd to repo root (parent of tool/)
cd "$(dirname "$0")/.."

# ---------- colored logging ----------
if [[ -t 1 ]]; then
  C_BLUE=$'\033[1;34m'; C_GREEN=$'\033[1;32m'; C_YELLOW=$'\033[1;33m'
  C_RED=$'\033[1;31m'; C_RESET=$'\033[0m'
else
  C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_RESET=""
fi
log()  { printf "%s[dev]%s %s\n"  "$C_BLUE"   "$C_RESET" "$*"; }
ok()   { printf "%s[ok ]%s %s\n"  "$C_GREEN"  "$C_RESET" "$*"; }
warn() { printf "%s[warn]%s %s\n" "$C_YELLOW" "$C_RESET" "$*"; }
err()  { printf "%s[err]%s %s\n"  "$C_RED"    "$C_RESET" "$*" >&2; }

# Pick `fvm flutter` if the project has .fvm/, else plain `flutter`
if [[ -d .fvm ]] && command -v fvm >/dev/null 2>&1; then
  FLUTTER="fvm flutter"
else
  FLUTTER="flutter"
fi

step() {
  local label="$1"; shift
  log "▶ $label"
  local start=$SECONDS
  if "$@"; then
    ok "$label ($((SECONDS - start))s)"
  else
    local code=$?
    err "$label failed (exit $code)"
    exit $code
  fi
}

# ---------- commands ----------
cmd_apk() {
  step "flutter clean"    $FLUTTER clean
  step "flutter pub get"  $FLUTTER pub get
  step "flutter build apk $*" $FLUTTER build apk "$@"
  ok "APK → build/app/outputs/flutter-apk/"
}

cmd_aab() {
  step "flutter clean"    $FLUTTER clean
  step "flutter pub get"  $FLUTTER pub get
  step "flutter build appbundle --release $*" $FLUTTER build appbundle --release "$@"
  ok "AAB → build/app/outputs/bundle/"
}

cmd_ipa() {
  local entry="${1:-lib/main_gcp.dart}"
  [[ $# -gt 0 ]] && shift || true
  step "flutter clean"   $FLUTTER clean
  step "flutter pub get" $FLUTTER pub get
  if [[ -d ios ]]; then
    step "rm ios/.symlinks + ios/Pods" rm -rf ios/.symlinks ios/Pods
    step "pod install --repo-update" bash -c "cd ios && pod install --repo-update"
  fi
  step "flutter build ipa --release -t $entry $*" \
    $FLUTTER build ipa --release -t "$entry" "$@"
  ok "IPA → build/ios/ipa/"
}

cmd_refresh() {
  step "flutter clean"   $FLUTTER clean
  step "flutter pub get" $FLUTTER pub get
}

cmd_gen() {
  step "flutter pub get" $FLUTTER pub get
  step "build_runner build --delete-conflicting-outputs" \
    $FLUTTER pub run build_runner build --delete-conflicting-outputs "$@"
  ok "Code generation complete"
}

cmd_gen_watch() {
  log "▶ build_runner watch (Ctrl+C to stop)"
  $FLUTTER pub run build_runner watch --delete-conflicting-outputs "$@"
}

cmd_nuke() {
  warn "Wiping Pods, Podfile.lock, build/, DerivedData…"
  step "flutter clean"           $FLUTTER clean
  step "rm build/"               rm -rf build
  if [[ -d ios ]]; then
    step "rm ios/Pods + Podfile.lock" rm -rf ios/Pods ios/Podfile.lock
  fi
  if [[ -d "$HOME/Library/Developer/Xcode/DerivedData" ]]; then
    step "rm DerivedData"        rm -rf "$HOME/Library/Developer/Xcode/DerivedData"
  fi
  step "flutter pub get"         $FLUTTER pub get
  if [[ -d ios ]]; then
    step "pod install --repo-update" bash -c "cd ios && pod install --repo-update"
  fi
  ok "Nuke complete."
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [args...]

Commands:
  apk [flags]                    Clean + pub get + build APK
  aab [flags]                    Clean + pub get + build App Bundle (release)
  ipa [entrypoint] [flags]       Clean + pub get + pod install + build IPA (release)
                                 Default entrypoint: lib/main_gcp.dart
  refresh                        Clean + pub get
  gen                            pub get + build_runner build --delete-conflicting-outputs
  watch                          build_runner watch --delete-conflicting-outputs
  nuke                           Full reset: Pods, DerivedData, build/
  help                           Show this

Examples:
  ./tool/dev.sh apk --release --flavor prod
  ./tool/dev.sh ipa lib/main_staging.dart --no-codesign
  ./tool/dev.sh aab --flavor prod -t lib/main_prod.dart
EOF
}

main() {
  local cmd="${1:-help}"
  [[ $# -gt 0 ]] && shift || true
  case "$cmd" in
    apk)     cmd_apk "$@" ;;
    aab)     cmd_aab "$@" ;;
    ipa)     cmd_ipa "$@" ;;
    refresh) cmd_refresh ;;
    gen)     cmd_gen "$@" ;;
    watch)   cmd_gen_watch "$@" ;;
    nuke)    cmd_nuke ;;
    help|-h|--help) usage ;;
    *) err "Unknown command: $cmd"; usage; exit 1 ;;
  esac
}

main "$@"
