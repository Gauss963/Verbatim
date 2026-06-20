#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_ROOT="${HOME}/.verbatim"
WHISPER_DIR="${CACHE_ROOT}/whisper.cpp"
MODEL_FILE="${CACHE_ROOT}/models/ggml-large-v3.bin"
VENDOR_DIR="${WORKSPACE_ROOT}/Vendor"
APP_MODEL_DIR="${WORKSPACE_ROOT}/Verbatim/Verbatim/models"

mkdir -p "${CACHE_ROOT}/models" "${VENDOR_DIR}" "${APP_MODEL_DIR}"

if [ ! -d "${WHISPER_DIR}/.git" ]; then
  git clone https://github.com/ggml-org/whisper.cpp.git "${WHISPER_DIR}"
else
  git -C "${WHISPER_DIR}" pull --ff-only
fi

if [ ! -f "${MODEL_FILE}" ]; then
  curl -L --fail --continue-at - \
    -o "${MODEL_FILE}" \
    "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin"
fi

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
  "${WHISPER_DIR}/build-xcframework.sh"

rsync -a --delete "${WHISPER_DIR}/build-apple/whisper.xcframework" "${VENDOR_DIR}/"
rsync -a "${MODEL_FILE}" "${APP_MODEL_DIR}/"

echo "Ready:"
echo "  framework: ${VENDOR_DIR}/whisper.xcframework"
echo "  model:     ${APP_MODEL_DIR}/ggml-large-v3.bin"
