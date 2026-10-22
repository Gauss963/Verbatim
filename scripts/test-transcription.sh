#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/verbatim-tests.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
FRAMEWORK_DIR="${ROOT}/Vendor/whisper.xcframework/macos-arm64_x86_64"

xcrun swiftc -parse-as-library -swift-version 5 -target "$(uname -m)-apple-macosx15.7" \
  -F "$FRAMEWORK_DIR" -framework whisper \
  -Xlinker -rpath -Xlinker "$FRAMEWORK_DIR" \
  "${ROOT}/Verbatim/Verbatim/TranscriptModels.swift" \
  "${ROOT}/Verbatim/Verbatim/TranscriptionChunker.swift" \
  "${ROOT}/Verbatim/Verbatim/WhisperContext.swift" \
  "${ROOT}/Verbatim/Verbatim/WhisperTranscriber.swift" \
  "${ROOT}/Verbatim/Verbatim/AudioSampleDecoder.swift" \
  "${ROOT}/Tests/TranscriptionRegressionTests.swift" \
  -o "${TEST_DIR}/TranscriptionRegressionTests"

"${TEST_DIR}/TranscriptionRegressionTests" "$ROOT" "$@"
