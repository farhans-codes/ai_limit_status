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

find_dmgbuild_python() {
  local candidate
  local resolved_candidate
  local candidates=()

  if [[ -n "${DMGBUILD_PYTHON:-}" ]]; then
    candidates+=("$DMGBUILD_PYTHON")
  fi

  candidates+=(
    python3.15
    python3.14
    python3.13
    python3.12
    python3.11
    python3.10
    python3
  )

  for candidate in "${candidates[@]}"; do
    if resolved_candidate="$(command -v "$candidate" 2>/dev/null)" &&
      "$resolved_candidate" -c \
        'import sys; raise SystemExit(sys.version_info < (3, 10))'; then
      printf '%s\n' "$resolved_candidate"
      return 0
    fi
  done

  return 1
}

if [[ ! -d "$app_path" ]]; then
  echo "Application bundle not found: $app_path" >&2
  exit 66
fi

if [[ ! -f "$background_png" ]]; then
  echo "DMG background not found: $background_png" >&2
  exit 66
fi

if ! python_bin="$(find_dmgbuild_python)"; then
  echo "Python 3.10 or newer is required to build the macOS DMG." >&2
  echo "Set DMGBUILD_PYTHON to a compatible interpreter and try again." >&2
  exit 69
fi

mkdir -p "$(dirname "$output_dmg")"
"$python_bin" -m venv --clear "$venv_path"
"$venv_path/bin/python" -m pip install \
  --disable-pip-version-check \
  --quiet \
  --requirement "$requirements_path"

"$venv_path/bin/python" - \
  "$settings_path" "$app_path" "$output_dmg" "$background_png" <<'PY'
import filecmp
from pathlib import Path
import sys

from dmgbuild import build_dmg
from ds_store import DSStore
from mac_alias import Alias


settings_path, app_path, output_dmg, background_png = sys.argv[1:]
app_name = "AI Limit Status.app"
resource = Path("Contents/Resources/dmg-background.png")
bundled_background = Path(app_path) / resource
if not bundled_background.is_file():
    raise SystemExit("Rebuild the macOS app to include the DMG background resource.")
if not filecmp.cmp(bundled_background, background_png, shallow=False):
    raise SystemExit("The bundled DMG background is outdated; rebuild the macOS app.")

mount_point = None


def configure_background(event):
    global mount_point
    if (
        event.get("type") == "command::finished"
        and event.get("command") == "hdiutil::attach"
    ):
        if event.get("ret") == 0:
            mount_point = next(
                Path(item["mount-point"])
                for item in event["output"]["system-entities"]
                if "mount-point" in item
            )
    if (
        event.get("type") == "operation::finished"
        and event.get("operation") == "dsstore::create"
    ):
        if mount_point is None:
            raise RuntimeError("The DMG mount point is unavailable.")
        # The resource is included before Xcode signs the app. Updating only
        # Finder metadata preserves that signature and leaves no PNG at root.
        background = mount_point / app_name / resource
        with DSStore.open(str(mount_point / ".DS_Store"), "r+") as store:
            icon_view = store["."]["icvp"]
            icon_view["backgroundType"] = 2
            alias = Alias.for_file(str(background))
            icon_view["backgroundImageAlias"] = alias.to_bytes()
            store["."]["icvp"] = icon_view
    if event.get("type", "").startswith("error::"):
        print(event.get("message", "DMG creation failed."), file=sys.stderr)


build_dmg(
    output_dmg,
    "AI Limit Status",
    settings_file=settings_path,
    defines={"app": app_path},
    callback=configure_background,
)
PY

hdiutil verify "$output_dmg"
