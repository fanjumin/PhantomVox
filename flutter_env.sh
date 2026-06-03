#!/bin/bash
# PhantomVox Flutter build helper
# Usage: source fl.sh && fl_build
export FLUTTER_ROOT="$HOME/flutter/flutter"
export DART_BIN="$FLUTTER_ROOT/bin/cache/dart-sdk/bin"
export PATH="$DART_BIN:$PATH"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

fl_build() {
  cd "$(dirname "$0")/phantomvox_app"
  local mode="${1:-debug}"
  local build_dir="build/linux/x64/$mode"
  mkdir -p "$build_dir"
  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=$(echo $mode | sed 's/.*/\u&/') \
    -DCMAKE_CXX_COMPILER=/usr/bin/g++ \
    -DFLUTTER_TARGET_PLATFORM=linux-x64 \
    -S linux -B "$build_dir" && \
  ninja -C "$build_dir" install
}
