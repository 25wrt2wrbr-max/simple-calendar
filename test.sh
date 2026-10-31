#!/bin/bash
# Runs the logic checks (no GUI needed).
set -euo pipefail
cd "$(dirname "$0")"

SDK="$(xcrun --show-sdk-path)"
ARCH="${ARCH:-$(uname -m)}"
BIN="build/logic-tests"

mkdir -p build
swiftc \
  -swift-version 5 \
  -parse-as-library \
  -sdk "$SDK" \
  -target "$ARCH-apple-macosx14.0" \
  -o "$BIN" \
  Sources/SimpleCalendar/CalendarModel.swift \
  Sources/SimpleCalendar/JumpParser.swift \
  Sources/SimpleCalendar/Keyboard.swift \
  Sources/SimpleCalendar/Support.swift \
  scripts/test.swift

"$BIN"
