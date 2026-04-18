# flutter-dev-toolkit

Shell helpers for daily Flutter development — short aliases and compound pipelines for clean, pub get, build, code-gen, and artifact management. Works on macOS (zsh) and Windows (PowerShell).

Turn this:

```bash
flutter clean
flutter pub get
rm -rf ios/.symlinks ios/Pods
cd ios && pod install --repo-update && cd ..
flutter build ipa --release -t lib/main.dart
```

Into this:

```bash
fbipa
```

## Features

- **Short aliases** for every common Flutter command (`fc`, `fpg`, `fr`, `fa`, `ft`, ...).
- **Compound build pipelines** — `fbapk`, `fbaab`, `fbipa` run clean + pub get + build in order with timing and fail-fast.
- **Code generation** helpers for `build_runner` (`fbr`, `fbrw`, `fbrc`, `fgen`).
- **FVM-aware** — auto-detects `.fvm/` and uses the pinned SDK.
- **Project-root detection** — walks up looking for `pubspec.yaml`, so commands work from subfolders.
- **Colored step-by-step output** with timing, stops on first failure.
- **Cross-platform** — zsh for macOS/Linux, PowerShell for Windows.
- **Team-shareable** — drop `tool/dev.sh` or `tool/dev.ps1` into each repo for CI and teammates who don't want personal shell config.

## Install

### macOS / Linux (zsh)

```bash
git clone https://github.com/ahmedemam22/flutter-dev-toolkit.git ~/flutter-dev-toolkit
cd ~/flutter-dev-toolkit/macos
chmod +x install.sh ../tool/dev.sh
./install.sh
source ~/.zshrc
fhelp
```

> **Tip:** `install.sh` copies `zsh_flutter` to `~/.zsh_flutter`. If you'd rather have `git pull` instantly update your helpers without reinstalling, swap the copy for a symlink:
> ```bash
> rm ~/.zsh_flutter
> ln -s ~/flutter-dev-toolkit/macos/zsh_flutter ~/.zsh_flutter
> rflutter
> ```

### Windows (PowerShell)

Open PowerShell (not cmd), then:

```powershell
git clone https://github.com/ahmedemam22/flutter-dev-toolkit.git "$env:USERPROFILE\flutter-dev-toolkit"
cd "$env:USERPROFILE\flutter-dev-toolkit\windows"
.\install.ps1
. $PROFILE
fhelp
```

If PowerShell refuses to run the script, allow local scripts once:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

## Cheat sheet

### Single commands

| Alias | Does |
|---|---|
| `fc` | `flutter clean` |
| `fpg` | `flutter pub get` |
| `fpu` | `flutter pub upgrade` |
| `fpo` | `flutter pub outdated` |
| `fa` | `flutter analyze` |
| `ft` | `flutter test` |
| `fr` / `frr` | `flutter run` / `flutter run --release` |
| `fdo` | `flutter doctor -v` |
| `fdev` | `flutter devices` |

### Build pipelines

| Alias | macOS | Windows | Does |
|---|---|---|---|
| `fbapk [flags]` | yes | yes | clean + pub get + `build apk` |
| `fbaab [flags]` | yes | yes | clean + pub get + `build appbundle --release` |
| `fbipa [entrypoint] [flags]` | yes | no* | clean + pub get + rm `ios/.symlinks`+`ios/Pods` + `pod install --repo-update` + `build ipa --release` |

\* iOS IPA builds require macOS + Xcode. On Windows use a Mac, Codemagic, or GitHub Actions macOS runners.

### Code generation (build_runner)

| Alias | Does |
|---|---|
| `fbr` | `build_runner build --delete-conflicting-outputs` |
| `fbrw` | `build_runner watch --delete-conflicting-outputs` |
| `fbrc` | `build_runner clean` |
| `fgen` | `pub get` + `build_runner build --delete-conflicting-outputs` |

### Utilities

| Alias | Does |
|---|---|
| `fcp` / `frefresh` | clean + pub get (no build) |
| `fnuke` | wipe caches + reinstall (`ios/Pods` + `ios/.symlinks` + DerivedData on macOS; `.dart_tool` + `build/` on both) |
| `fopen apk` / `fopen ipa` / `fopen aab` | open artifact folder in Finder / Explorer |
| `finfo` | environment sanity check |
| `rflutter` | reload config after editing the script |
| `fhelp` | print in-terminal cheat sheet |

## Examples

```bash
fbapk                               # debug APK
fbapk --release --flavor prod       # release APK with flavor
fbipa                               # release IPA (macOS), uses lib/main.dart
fbipa lib/main_staging.dart         # custom entrypoint
fbipa lib/main.dart --no-codesign

fgen                                # one-shot code generation
fbrw                                # watch mode — auto-regen on save

fnuke                               # nuke everything and rebuild
```

## Per-project scripts (team / CI)

Copy the `tool/` folder into any Flutter repo and commit it. Teammates and CI use the exact same pipelines without installing personal shell config.

```bash
cp -r ~/flutter-dev-toolkit/tool .
chmod +x tool/dev.sh
git add tool/ && git commit -m "chore: add build pipeline scripts"
```

Then everyone runs:

```bash
./tool/dev.sh apk --release           # macOS / Linux
./tool/dev.sh ipa lib/main.dart   # macOS only
./tool/dev.sh gen
./tool/dev.sh refresh
./tool/dev.sh nuke
```

```powershell
.\tool\dev.ps1 apk --release          # Windows
.\tool\dev.ps1 gen
.\tool\dev.ps1 refresh
```

### Bitbucket Pipelines example

```yaml
- step:
    name: Build release APK
    image: ghcr.io/cirruslabs/flutter:stable
    script:
      - ./tool/dev.sh apk --release
    artifacts:
      - build/app/outputs/flutter-apk/*.apk
```

## FVM support

If a project has a `.fvm/` folder and `fvm` is on PATH, every command automatically switches to `fvm flutter` under the hood. No config required.

## Android Studio / IntelliJ terminal integration

**macOS:** Settings → Tools → Terminal → Shell path: `/bin/zsh -l`

**Windows:** Settings → Tools → Terminal → Shell path: `powershell.exe` (or `pwsh.exe` for PowerShell 7+). Close and reopen the terminal tab afterwards. `fhelp` should work inside the IDE.

## Troubleshooting

**`flutter: command not found` (macOS)** — add Flutter to PATH *before* the source line in `~/.zshrc`:
```bash
export PATH="$HOME/development/flutter/bin:$PATH"
```

**`flutter` not recognized (Windows)** — add Flutter's `bin` folder to your user PATH via System Properties → Environment Variables, then restart PowerShell.

**`pod install` fails during `fbipa`** — `sudo gem install cocoapods && xcode-select --install`. Still flaky? `fnuke` wipes DerivedData and Pods and reinstalls.

**Dart/Flutter version drift across machines** — adopt [FVM](https://fvm.app):
```bash
brew install fvm
cd your-project
fvm use 3.24.0            # pins .fvm/fvm_config.json
```

**PowerShell: cannot run scripts** —
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

**Colors don't render in Android Studio terminal (macOS)** — add `export TERM=xterm-256color` before the source line in `~/.zshrc`.

## Updating

```bash
cd ~/flutter-dev-toolkit
git pull
```

On **Windows**, `$PROFILE` dot-sources the file in the repo directly, so changes are live after:

```powershell
. $PROFILE
```

On **macOS**, behavior depends on how you installed:

- **Symlink** (recommended for contributors) — just run `rflutter`.
- **Copy** (default from `./install.sh`) — re-run `./macos/install.sh` to refresh the copy, then `source ~/.zshrc`.

## Repo layout

```
flutter-dev-toolkit/
├── README.md
├── LICENSE               MIT
├── .gitignore
├── macos/
│   ├── zsh_flutter       macOS/Linux shell helpers
│   └── install.sh        macOS/Linux installer
├── windows/
│   ├── flutter.ps1       Windows PowerShell helpers
│   └── install.ps1       Windows installer
└── tool/
    ├── dev.sh            cross-platform bash build script (drop into Flutter projects)
    └── dev.ps1           Windows PowerShell build script (drop into Flutter projects)
```

## Contributing

PRs welcome. Keep:
- Command names consistent across platforms (`fbapk`, `fbipa`, `fgen`, ...).
- Fail-fast semantics — any failed step stops the pipeline with the original exit code.
- No external dependencies beyond a working Flutter SDK.

## License

MIT — see [LICENSE](LICENSE).
