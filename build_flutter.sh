#!/bin/bash
export FLUTTER_ROOT="$HOME/flutter/flutter"
export DART_BIN="$FLUTTER_ROOT/bin/cache/dart-sdk/bin"
export FLUTTER_TOOL="$FLUTTER_ROOT/bin/cache/flutter_tools.snapshot"
export PATH="$DART_BIN:$PATH"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

cd "$(dirname "$0")/../phantomvox_app"

# CMake: use make instead of ninja
export CMAKE_MAKE_PROGRAM=$(which make)
export CMAKE_CXX_COMPILER=$(which g++)

dart "$FLUTTER_TOOL" build linux --debug "$@"
