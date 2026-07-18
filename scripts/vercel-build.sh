#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.46.0-0.3.pre}"
FLUTTER_HOME="${FLUTTER_HOME:-/tmp/flutter}"

if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 --branch "$FLUTTER_VERSION" "$FLUTTER_HOME"
fi

export PATH="$FLUTTER_HOME/bin:$PATH"

flutter --version
flutter config --enable-web --no-analytics
flutter pub get
flutter build web --release --base-href /
