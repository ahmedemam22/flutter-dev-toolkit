#!/usr/bin/env bash
# install.sh — one-shot installer for Flutter zsh helpers
# Run from inside this folder: ./install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="$HOME/.zsh_flutter"
ZSHRC="$HOME/.zshrc"
SRC_LINE='[[ -f "$HOME/.zsh_flutter" ]] && source "$HOME/.zsh_flutter"'

echo "▶ Installing Flutter zsh helpers…"

# 1. Copy (or symlink) zsh_flutter to $HOME
if [[ -f "$TARGET" ]] && ! cmp -s "$SCRIPT_DIR/zsh_flutter" "$TARGET"; then
  cp "$TARGET" "$TARGET.bak.$(date +%s)"
  echo "  • Backed up existing ~/.zsh_flutter"
fi
cp "$SCRIPT_DIR/zsh_flutter" "$TARGET"
echo "  • Installed $TARGET"

# 2. Ensure ~/.zshrc sources it
touch "$ZSHRC"
if ! grep -Fq "$SRC_LINE" "$ZSHRC"; then
  {
    echo ""
    echo "# Flutter workflow helpers"
    echo "$SRC_LINE"
  } >> "$ZSHRC"
  echo "  • Added source line to ~/.zshrc"
else
  echo "  • ~/.zshrc already sources it — skipping"
fi

# 3. Make tool/dev.sh executable if we're alongside it
if [[ -f "$SCRIPT_DIR/tool/dev.sh" ]]; then
  chmod +x "$SCRIPT_DIR/tool/dev.sh"
fi

echo ""
echo "✅ Installed. Reload your shell:"
echo "    source ~/.zshrc"
echo ""
echo "Then try:  fhelp"
