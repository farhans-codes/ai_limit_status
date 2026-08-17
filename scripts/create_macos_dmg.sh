#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <app-path> <output-dmg> <background-png>" >&2
  exit 64
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

absolute_path() {
  if [[ "$1" == /* ]]; then
    printf '%s\n' "$1"
  else
    printf '%s/%s\n' "$PWD" "$1"
  fi
}

app_path="$(absolute_path "$1")"
output_dmg="$(absolute_path "$2")"
background_png="$(absolute_path "$3")"
settings_path="$repo_root/installer/macos/dmg-settings.py"
requirements_path="$repo_root/installer/macos/requirements.txt"
venv_path="$repo_root/build/dmgbuild-venv"

if [[ ! -d "$app_path" ]]; then
  echo "Application bundle not found: $app_path" >&2
  exit 66
fi

if [[ ! -f "$background_png" ]]; then
  echo "DMG background not found: $background_png" >&2
  exit 66
fi

mkdir -p "$(dirname "$output_dmg")"
python3 -m venv "$venv_path"
"$venv_path/bin/python" -m pip install \
  --disable-pip-version-check \
  --quiet \
  --requirement "$requirements_path"

"$venv_path/bin/dmgbuild" \
  -s "$settings_path" \
  -D "app=$app_path" \
  -D "background=$background_png" \
  "AI Limit Status" \
  "$output_dmg"

hdiutil verify "$output_dmg"
