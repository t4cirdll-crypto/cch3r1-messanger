#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

flutter_version=3.27.1
sdk_root="$PWD/.hoplite/cache/flutter"
mkdir -p .hoplite/cache .hoplite/logs

if [[ ! -x "$sdk_root/bin/flutter" ]]; then
  python3 - "$flutter_version" <<'PY'
import hashlib
import json
import pathlib
import sys
import urllib.request

version = sys.argv[1]
base = "https://storage.googleapis.com/flutter_infra_release/releases/"
with urllib.request.urlopen(base + "releases_linux.json", timeout=60) as response:
    releases = json.load(response)["releases"]
release = next(item for item in releases if item["version"] == version and item["channel"] == "stable")
archive = pathlib.Path(".hoplite/cache/flutter.tar.xz")
urllib.request.urlretrieve(base + release["archive"], archive)
digest = hashlib.file_digest(archive.open("rb"), "sha256").hexdigest()
if digest != release["sha256"]:
    archive.unlink()
    raise SystemExit("Flutter archive checksum mismatch")
PY
  tar -xf .hoplite/cache/flutter.tar.xz -C .hoplite/cache
  rm .hoplite/cache/flutter.tar.xz
fi

export PATH="$sdk_root/bin:$PATH"
export CI=true
# The cached SDK is provisioned by a different sandbox user.  Trust only this
# known checkout so Flutter's internal Git probe does not abort its bootstrap.
if ! git config --global --get-all safe.directory | grep -Fx -- "$sdk_root" >/dev/null; then
  git config --global --add safe.directory "$sdk_root"
fi
flutter config --no-analytics --enable-web
flutter --version
flutter pub get
dart run build_runner build --delete-conflicting-outputs --low-resources-mode
