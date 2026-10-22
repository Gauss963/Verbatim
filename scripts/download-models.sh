#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL_DIR="${ROOT}/Verbatim/Verbatim/models"
REVISION="5359861c739e955e79d9a303bcbc70fb988958b1"
TEMP_FILE=""
trap 'if [[ -n "$TEMP_FILE" ]]; then rm -f "$TEMP_FILE"; fi' EXIT
mkdir -p "$MODEL_DIR"

while read -r checksum filename; do
  destination="${MODEL_DIR}/${filename}"
  if [[ -f "$destination" ]] && \
    printf '%s  %s\n' "$checksum" "$destination" | shasum -a 256 --check --status; then
    echo "Verified: $filename"
    continue
  fi

  echo "Downloading: $filename"
  TEMP_FILE="$(mktemp "${TMPDIR:-/tmp}/verbatim-model.XXXXXX")"
  curl --fail --location --retry 5 --retry-delay 5 \
    --output "$TEMP_FILE" \
    "https://huggingface.co/ggerganov/whisper.cpp/resolve/${REVISION}/${filename}"
  printf '%s  %s\n' "$checksum" "$TEMP_FILE" | shasum -a 256 --check
  mv "$TEMP_FILE" "$destination"
  TEMP_FILE=""
done < "${ROOT}/scripts/models.sha256"
