# Verbatim

[![Build macOS App](https://github.com/Gauss963/Verbatim/actions/workflows/macos-build.yml/badge.svg)](https://github.com/Gauss963/Verbatim/actions/workflows/macos-build.yml)

Verbatim is a native SwiftUI app for local audio and video transcription with selectable Whisper models.

The app is designed for private, offline-first transcription: media files stay on the device, the Whisper model runs locally, and generated transcripts can be reviewed, copied, and played back alongside the original audio or video.

## Features

- Native SwiftUI macOS interface.
- Local Whisper transcription with Base, Small, and Large v3 model choices.
- Drag and drop audio or video files into the queue.
- File picker support for common media formats.
- Voice Memos picker shortcut on macOS.
- Language selection for Auto, Chinese, and English.
- Manual Start Transcription button.
- Queue status, per-run progress, and failure display.
- Full transcript copy button.
- Apple Music-style transcript view with large scrolling text.
- Audio playback synced with highlighted transcript segments.
- Video preview when the selected transcript source is a video file.
- Bundled `whisper.framework` and Whisper model files for a self-contained app build.

## Supported Inputs

Verbatim currently accepts:

- `.mp3`
- `.mp4`
- `.m4a`
- `.wav`
- `.aiff`
- `.aif`
- `.mov`
- `.aac`
- `.flac`

## Requirements

For development:

- macOS 15.7 or newer, based on the current Xcode deployment target.
- Xcode 26 or newer recommended.
- Apple silicon Mac recommended for Large v3 local inference.
- About 3.6 GB of local disk space for the bundled Base, Small, and Large v3 models.

For people using a packaged build:

- macOS 15.7 or newer.
- Enough free disk space for the app bundle, which includes the Whisper model.

## Repository Layout

```text
Verbatim/
  Verbatim.xcodeproj
  Verbatim/
    ContentView.swift
    TranscriptionViewModel.swift
    WhisperTranscriber.swift
    WhisperContext.swift
    PlaybackController.swift
    AudioSampleDecoder.swift
    TranscriptModels.swift
    VoiceMemoImporter.swift
    Assets.xcassets/
    models/
      ggml-base.bin
      ggml-small.bin
      ggml-large-v3.bin
Vendor/
  whisper.xcframework
scripts/
  setup-whisper.sh
```

## Model And Binary Assets

The app ships with three multilingual Whisper models:

```text
Verbatim/Verbatim/models/ggml-base.bin
Verbatim/Verbatim/models/ggml-small.bin
Verbatim/Verbatim/models/ggml-large-v3.bin
```

These models are not committed to git because they are larger than GitHub's normal repository file limit. GitHub blocks files larger than 100 MB in regular git history, and release assets are the right place for distributable binaries.

Model choices in the app:

- Base: smallest and fastest option for iPhone and iPad.
- Small: balanced option for iPhone and iPad.
- Large v3: highest accuracy option, best suited to Mac or short mobile files.

The local development machine currently has the model files in place, and packaged `.app` builds include them under:

```text
Verbatim.app/Contents/Resources/ggml-base.bin
Verbatim.app/Contents/Resources/ggml-small.bin
Verbatim.app/Contents/Resources/ggml-large-v3.bin
```

## Setting Up Whisper

Run the setup script from the repository root:

```sh
scripts/setup-whisper.sh
```

The script is responsible for preparing the local Whisper dependency chain used by the Xcode project. After setup, confirm these files exist:

```text
Vendor/whisper.xcframework
Verbatim/Verbatim/models/ggml-large-v3.bin
Verbatim/Verbatim/models/ggml-small.bin
Verbatim/Verbatim/models/ggml-base.bin
```

## Building In Xcode

Open the project:

```sh
open Verbatim/Verbatim.xcodeproj
```

Then choose the `Verbatim` scheme and build for macOS.

## Building From Terminal

Debug build:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project Verbatim/Verbatim.xcodeproj \
  -scheme Verbatim \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

For a distributable Release build, use the same script as GitHub Actions:

```sh
bash scripts/build-macos.sh
```

This downloads missing models from a pinned upstream revision, verifies their SHA-256 hashes, builds both `arm64` and `x86_64`, signs the embedded framework and app with an ad-hoc signature, and verifies the finished bundle. The committed `Vendor/whisper.xcframework` is used directly; no Whisper rebuild or Apple Developer certificate is required.

Optional version overrides:

```sh
VERSION=1.0.3 BUILD_NUMBER=3 bash scripts/build-macos.sh
```

## Packaging A Shareable App

All three models are included. Outputs are:

```text
dist/Verbatim.app
dist/Verbatim-macOS-universal-v<VERSION>.zip
dist/SHA256SUMS.txt
```

The single ZIP can be sent directly to another person. They can extract it and move `Verbatim.app` into Applications. The universal app supports both Apple silicon and Intel Macs running macOS 15.7 or newer.

Before sharing a package, verify the ZIP and the extracted app:

```sh
cd dist
shasum -a 256 -c SHA256SUMS.txt
CHECK_DIR="$(mktemp -d)"
ditto -x -k Verbatim-macOS-universal-v*.zip "$CHECK_DIR"
codesign --verify --deep --strict --verbose=2 "$CHECK_DIR/Verbatim.app"
```

This project currently uses ad-hoc signing, not Developer ID signing or notarization. A downloaded build may require explicit approval in System Settings > Privacy & Security. Do not disable Gatekeeper system-wide.

## Automatic macOS Builds

Every push to `main` runs [Build macOS App](https://github.com/Gauss963/Verbatim/actions/workflows/macos-build.yml). The workflow can also be started manually with **Run workflow**.

The workflow uses a GitHub-hosted macOS runner with Xcode 26.3 and:

- Restores the three Whisper models from cache or downloads them when missing.
- Verifies every model against `scripts/models.sha256`, including cached copies.
- Runs `scripts/build-macos.sh` to produce a verified universal Release app.
- Uploads the single app ZIP and checksum as an artifact named `Verbatim-macOS-<commit SHA>`.

To download a build, open a successful run and select its artifact under **Artifacts**. GitHub wraps the artifact in an outer archive; extract that first, then extract the inner Verbatim ZIP to get the app. Artifacts are retained for 14 days and downloading them requires GitHub sign-in. Stable GitHub Releases remain available separately.

The workflow uses pinned action revisions, requires no signing secrets, and does not change the source branch. The build job has read-only repository access; only the release job receives permission to upload release assets.

## GitHub Releases

Do not commit the packaged app, zip, or model file into git history.

To publish a stable release, push a version tag on the desired commit:

```sh
git tag v1.0.3
git push origin v1.0.3
```

The tag workflow builds the app with that version, verifies the archive, uploads all assets to a draft release, and publishes it only after uploads succeed. The tag must use `vMAJOR.MINOR.PATCH`. A failed upload leaves the release as a draft; rerunning the job retries the assets.

GitHub Release assets have a per-file size limit, so the full app ZIP is split into parts smaller than 2 GiB. This restriction does not change the single-ZIP format used locally or inside Actions artifacts.

Download all `.part-*` assets and both checksum files from a release into one folder. For v1.0.3, reconstruct and verify with:

```sh
shasum -a 256 -c SHA256SUMS.txt
cat Verbatim-macOS-universal.zip.part-* > Verbatim-macOS-universal-v1.0.3.zip
shasum -a 256 -c ZIP-SHA256SUMS.txt
```

Extract the reconstructed ZIP normally to get `Verbatim.app`.

## Current Limitations

- The packaged app is currently ad-hoc signed, not notarized.
- The app is being developed as an Apple-native project, but the tested packaged build is macOS.
- Whisper Large v3 is accurate but heavy; use Base or Small for lighter iPhone/iPad runs.
- Transcript highlighting depends on segment timing returned by Whisper.

## Roadmap

- Developer ID signing and notarization.
- Developer ID signing secrets for automated releases.
- Better progress estimates during active Whisper inference.
- More language presets.
- iOS/iPadOS packaging work after the local model and media import flow are tuned for those platforms.
