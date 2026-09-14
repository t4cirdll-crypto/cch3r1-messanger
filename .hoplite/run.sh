#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
sdk_root="$PWD/.hoplite/cache/flutter"
export PATH="$sdk_root/bin:$PATH"
export CI=true
if ! git config --global --get-all safe.directory | grep -Fx -- "$sdk_root" >/dev/null; then
  git config --global --add safe.directory "$sdk_root"
fi

mkdir -p .hoplite/logs
flutter build web --release --no-pub --target=tool/preview.dart --no-web-resources-cdn \
  2>&1 | tee .hoplite/logs/preview-build.log
exec python3 -m http.server 3000 --bind 0.0.0.0 --directory build/web
