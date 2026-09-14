#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -x .hoplite/cache/flutter/bin/flutter ]]; then
  export PATH="$PWD/.hoplite/cache/flutter/bin:$PATH"
fi
export CI=true
mkdir -p .hoplite/logs

flutter analyze --no-pub 2>&1 | tee .hoplite/logs/analyze.log
flutter test --no-pub --concurrency=1 2>&1 | tee .hoplite/logs/test.log
git diff --check
git diff --stat
