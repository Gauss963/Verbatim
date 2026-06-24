#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_ROOT="${HOME}/.verbatim"
WHISPER_DIR="${CACHE_ROOT}/whisper.cpp"
MODEL_NAMES=(
  "ggml-base.bin"
  "ggml-small.bin"
  "ggml-large-v3.bin"
)
VENDOR_DIR="${WORKSPACE_ROOT}/Vendor"
APP_MODEL_DIR="${WORKSPACE_ROOT}/Verbatim/Verbatim/models"

mkdir -p "${CACHE_ROOT}/models" "${VENDOR_DIR}" "${APP_MODEL_DIR}"

if [ ! -d "${WHISPER_DIR}/.git" ]; then
  git clone https://github.com/ggml-org/whisper.cpp.git "${WHISPER_DIR}"
else
  git -C "${WHISPER_DIR}" pull --ff-only
fi

for model_name in "${MODEL_NAMES[@]}"; do
  model_file="${CACHE_ROOT}/models/${model_name}"
  if [ ! -f "${model_file}" ]; then
    curl -L --fail --continue-at - \
      -o "${model_file}" \
      "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/${model_name}"
  fi
done

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
  "${WHISPER_DIR}/build-xcframework.sh"

rsync -a --delete "${WHISPER_DIR}/build-apple/whisper.xcframework" "${VENDOR_DIR}/"
for model_name in "${MODEL_NAMES[@]}"; do
  rsync -a "${CACHE_ROOT}/models/${model_name}" "${APP_MODEL_DIR}/"
done

echo "Ready:"
echo "  framework: ${VENDOR_DIR}/whisper.xcframework"
echo "  models:    ${APP_MODEL_DIR}/ggml-base.bin"
echo "             ${APP_MODEL_DIR}/ggml-small.bin"
echo "             ${APP_MODEL_DIR}/ggml-large-v3.bin"
