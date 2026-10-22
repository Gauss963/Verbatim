#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
DERIVED_DATA="${ROOT}/build/macOS"
OUTPUT_DIR="${ROOT}/dist"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/verbatim-package.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
APP="${STAGING_DIR}/Verbatim.app"

bash "${ROOT}/scripts/download-models.sh"
mkdir -p "$OUTPUT_DIR"

BUILD_SETTINGS=(
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGN_IDENTITY=
  DEVELOPMENT_TEAM=
)
if [[ -n "${VERSION:-}" ]]; then
  BUILD_SETTINGS+=("MARKETING_VERSION=${VERSION}")
fi
if [[ -n "${BUILD_NUMBER:-}" ]]; then
  BUILD_SETTINGS+=("CURRENT_PROJECT_VERSION=${BUILD_NUMBER}")
fi

xcodebuild \
  -project "${ROOT}/Verbatim/Verbatim.xcodeproj" \
  -scheme Verbatim \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  "${BUILD_SETTINGS[@]}" \
  build

# Stage outside the checkout so cloud providers cannot add Finder metadata while signing.
ditto --norsrc --noextattr "${DERIVED_DATA}/Build/Products/Release/Verbatim.app" "$APP"
xattr -cr "$APP"

# Sign the embedded framework before signing the enclosing app.
codesign --force --sign - --timestamp=none "$APP/Contents/Frameworks/whisper.framework"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
lipo "$APP/Contents/MacOS/Verbatim" -verify_arch arm64 x86_64
lipo "$APP/Contents/Frameworks/whisper.framework/whisper" -verify_arch arm64 x86_64
(
  cd "$APP/Contents/Resources"
  shasum -a 256 --check "${ROOT}/scripts/models.sha256"
)

APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
ZIP_NAME="Verbatim-macOS-universal-v${APP_VERSION}.zip"
ditto -c -k --sequesterRsrc --keepParent --zlibCompressionLevel 6 "$APP" "${OUTPUT_DIR}/${ZIP_NAME}"
if [[ -d "${OUTPUT_DIR}/Verbatim.app" ]]; then
  rm -rf "${OUTPUT_DIR}/Verbatim.app"
fi
ditto --norsrc --noextattr "$APP" "${OUTPUT_DIR}/Verbatim.app"
(
  cd "$OUTPUT_DIR"
  shasum -a 256 "$ZIP_NAME" > SHA256SUMS.txt
)

echo "App: ${OUTPUT_DIR}/Verbatim.app"
echo "ZIP: ${OUTPUT_DIR}/${ZIP_NAME}"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  printf 'zip_name=%s\n' "$ZIP_NAME" >> "$GITHUB_OUTPUT"
fi
