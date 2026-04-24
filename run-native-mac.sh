#!/bin/zsh
set -e

ROOT="/Users/millerm/Documents/Codex/2026-04-20-do-you-have-acess-to-any"
APP_DIR="$ROOT/dist/BubblePath.app"

if [[ ! -d "$APP_DIR" ]]; then
  "$ROOT/scripts/package-native-mac.sh"
fi

open "$APP_DIR"
