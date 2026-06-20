# Verbatim

Verbatim is a native SwiftUI app for local audio and video transcription with Whisper large-v3.

The app is designed for private, offline-first transcription: media files stay on the device, the Whisper model runs locally, and generated transcripts can be reviewed, copied, and played back alongside the original audio or video.

## Features

- Native SwiftUI macOS interface.
- Local Whisper large-v3 transcription.
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
- Bundled `whisper.framework` and `ggml-large-v3.bin` for a self-contained app build.

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
- Apple silicon Mac recommended for large-v3 local inference.
- About 3 GB of local disk space for the bundled large-v3 model.

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
      ggml-large-v3.bin
Vendor/
  whisper.xcframework
scripts/
  setup-whisper.sh
```

## Model And Binary Assets

The app expects Whisper large-v3 at:

```text
Verbatim/Verbatim/models/ggml-large-v3.bin
```

That model is not committed to git because it is far larger than GitHub's normal repository file limit. GitHub blocks files larger than 100 MB in regular git history, and release assets are the right place for distributable binaries.

The local development machine currently has the model file in place, and packaged `.app` builds include it under:

```text
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

Release build:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project Verbatim/Verbatim.xcodeproj \
  -scheme Verbatim \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  build
```

## Packaging A Shareable App

The app bundle is large because it contains Whisper large-v3. The packaged zip is expected to be roughly 2.7 GB.

The current local package output is:

```text
dist/Verbatim.zip
```

Before sharing a package, verify the app after unzipping:

```sh
rm -rf /tmp/verbatim-zipcheck
mkdir -p /tmp/verbatim-zipcheck
ditto -x -k dist/Verbatim.zip /tmp/verbatim-zipcheck
codesign --verify --deep --strict --verbose=2 /tmp/verbatim-zipcheck/Verbatim.app
```

This project currently uses ad-hoc signing for local builds. For a smoother public distribution experience, the app should eventually be signed with an Apple Developer ID certificate and notarized.

## GitHub Releases

Do not commit the packaged app, zip, or model file into git history.

Use GitHub Releases for downloadable builds. Since the full app zip is larger than 2 GB, split the archive into smaller assets before uploading:

```sh
mkdir -p release
split -b 1900m dist/Verbatim.zip release/Verbatim.zip.part-
shasum -a 256 release/Verbatim.zip.part-* > release/SHA256SUMS.txt
```

To reconstruct:

```sh
cat Verbatim.zip.part-* > Verbatim.zip
shasum -a 256 Verbatim.zip
```

## Current Limitations

- The packaged app is currently ad-hoc signed, not notarized.
- The app is being developed as an Apple-native project, but the tested packaged build is macOS.
- Whisper large-v3 is accurate but heavy; transcription can take time on long media files.
- Transcript highlighting depends on segment timing returned by Whisper.

## Roadmap

- Developer ID signing and notarization.
- A repeatable release script.
- Better progress estimates during active Whisper inference.
- More language presets.
- iOS/iPadOS packaging work after the local model and media import flow are tuned for those platforms.
