import SwiftUI
import UniformTypeIdentifiers
import AVKit

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct ContentView: View {
    @State private var model = TranscriptionViewModel()
    @State private var isDropTargeted = false
    @State private var isFileImporterPresented = false

    var body: some View {
        rootLayout
            .frame(minWidth: 980, minHeight: 620)
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.audio, .movie],
                allowsMultipleSelection: true
            ) { result in
                if case .success(let urls) = result {
                    model.addFiles(urls)
                }
            }
    }

    @ViewBuilder
    private var rootLayout: some View {
#if os(macOS)
        HSplitView {
            sidebar
                .frame(minWidth: 340, idealWidth: 360, maxWidth: 420, maxHeight: .infinity)

            transcriptPane
                .frame(minWidth: 620, maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(windowBackground)
#else
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 440)
        } detail: {
            transcriptPane
        }
#endif
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            sidebarHeader

            dropZone

            VStack(alignment: .leading, spacing: 10) {
                Text("Language")
                    .font(.headline)

                Picker("Language", selection: $model.language) {
                    ForEach(TranscriptLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Model")
                    .font(.headline)

                Picker("Model", selection: $model.selectedModel) {
                    ForEach(WhisperModel.allCases) { whisperModel in
                        Text(whisperModel.title).tag(whisperModel)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(model.isTranscribing)

                Text(model.selectedModel.shortDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            transcriptionControls

            queueSection
                .frame(maxHeight: .infinity, alignment: .top)

            if let status = model.environmentStatus {
                environmentStatusView(status)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 18)
        .padding(.top, sidebarTopPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(sidebarBackground)
        .task {
            model.refreshEnvironmentStatus()
        }
    }

    private var sidebarHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))

                Image(systemName: "waveform")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.tint)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("Verbatim")
                    .font(.headline)
                Text("Local Whisper transcription")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func environmentStatusView(_ status: EnvironmentStatus) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: status.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(status.tint)
                .frame(width: 14)

            Text(status.message)
                .font(.caption.weight(.medium))
                .foregroundStyle(status.tint)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(status.tint.opacity(0.16), lineWidth: 1)
        }
    }

    private var transcriptionControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    Task {
                        await model.transcribeSelectedFiles()
                    }
                } label: {
                    Label(model.isTranscribing ? "Transcribing" : "Start Transcription", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.files.isEmpty || model.isTranscribing)

                Button {
                    isFileImporterPresented = true
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(model.isTranscribing)
                .help("Add files")

#if os(macOS)
                Button {
                    model.addFiles(VoiceMemoImporter.chooseRecordings())
                } label: {
                    Image(systemName: "mic")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(model.isTranscribing)
                .help("Add from Voice Memos")
#endif
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(model.progressTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if model.isTranscribing {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                ProgressView(value: model.progressFraction, total: 1)
                    .opacity(model.files.isEmpty ? 0.35 : 1)

                if let currentFileName = model.currentFileName {
                    Text(currentFileName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(12)
            .background(panelBackground, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Queue")
                    .font(.headline)

                Spacer()

                if !model.files.isEmpty {
                    Text("\(model.files.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            if model.files.isEmpty {
                Text("Drop .mp3, .mp4, .m4a, .wav, or .mov files here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(model.files) { file in
                            fileRow(file)
                        }
                    }
                }
            }
        }
        .frame(minHeight: 120, maxHeight: .infinity, alignment: .top)
    }

    private var dropZone: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.tint)

            VStack(spacing: 4) {
                Text("Drop audio or video")
                    .font(.headline)
                Text("MP3, MP4, M4A, WAV, MOV")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button {
                isFileImporterPresented = true
            } label: {
                Label("Choose Files", systemImage: "plus")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.13) : panelBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.28), style: StrokeStyle(lineWidth: 1.5, dash: [7, 6]))
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            model.acceptDrop(providers)
        }
    }

    private func fileRow(_ file: TranscriptFile) -> some View {
        HStack(spacing: 10) {
            Image(systemName: file.iconName)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(file.url.lastPathComponent)
                    .lineLimit(1)
                Text(file.statusText)
                    .font(.caption)
                    .foregroundStyle(file.statusTint)
            }

            Spacer(minLength: 8)

            if file.state == .running {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                model.remove(file)
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .disabled(model.isTranscribing)
            .help("Remove")
        }
        .padding(10)
        .background(panelBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private var transcriptPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Transcript")
                            .font(.system(size: 24, weight: .semibold))
                        Text(model.outputSubtitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        Clipboard.copy(model.transcript)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .disabled(model.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if !model.transcript.isEmpty {
                    MediaPlaybackView(
                        title: model.playbackTitle,
                        player: model.playback.player,
                        showsVideo: model.playbackShowsVideo,
                        currentTime: model.playback.currentTime,
                        duration: model.playback.duration,
                        isPlaying: model.playback.isPlaying,
                        onPlayPause: model.playPauseTranscript,
                        onSeekFraction: model.seekPlayback(to:)
                    )
                }
            }
            .padding(24)

            Divider()

            ZStack(alignment: .topLeading) {
                if model.transcript.isEmpty {
                    ContentUnavailableView {
                        Label("No transcript yet", systemImage: "text.alignleft")
                    } description: {
                        Text("Add files on the left, choose a language, then transcribe locally.")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    LyricsTranscriptView(
                        segments: transcriptDisplaySegments,
                        activeSegmentID: model.activeSegmentID,
                        onSeek: model.seek(to:)
                    )
                }
            }
        }
        .background(windowBackground)
    }

    private var transcriptDisplaySegments: [TranscriptSegment] {
        if !model.transcriptSegments.isEmpty {
            return model.transcriptSegments
        }

        return model.transcript
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { TranscriptSegment(text: $0, startTime: nil, endTime: nil, sourceName: nil, sourceURL: nil) }
    }

    private var sidebarTopPadding: CGFloat {
#if os(macOS)
        42
#else
        24
#endif
    }

    private var sidebarBackground: Color {
#if os(macOS)
        Color(nsColor: .controlBackgroundColor)
#else
        Color(uiColor: .secondarySystemBackground)
#endif
    }

    private var panelBackground: Color {
#if os(macOS)
        Color(nsColor: .textBackgroundColor)
#else
        Color(uiColor: .systemBackground)
#endif
    }

    private var windowBackground: Color {
#if os(macOS)
        Color(nsColor: .windowBackgroundColor)
#else
        Color(uiColor: .systemBackground)
#endif
    }
}

private struct MediaPlaybackView: View {
    let title: String
    let player: AVPlayer
    let showsVideo: Bool
    let currentTime: TimeInterval
    let duration: TimeInterval
    let isPlaying: Bool
    let onPlayPause: () -> Void
    let onSeekFraction: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsVideo {
                VideoPlayer(player: player)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .frame(maxWidth: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.secondary.opacity(0.18))
                    }
            }

            HStack(spacing: 12) {
                Button(action: onPlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())
                .help(isPlaying ? "Pause" : "Play")

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Label(title, systemImage: showsVideo ? "film" : "waveform")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)

                        Spacer()

                        Text("\(formatted(currentTime)) / \(formatted(duration))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: Binding(
                            get: {
                                guard duration > 0 else { return 0 }
                                return min(1, max(0, currentTime / duration))
                            },
                            set: { onSeekFraction($0) }
                        ),
                        in: 0...1
                    )
                    .disabled(duration <= 0)
                }
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func formatted(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "0:00" }

        let totalSeconds = max(0, Int(seconds.rounded(.down)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct LyricsTranscriptView: View {
    let segments: [TranscriptSegment]
    let activeSegmentID: UUID?
    let onSeek: (TranscriptSegment) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 34) {
                    ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                        LyricsLineView(
                            segment: segment,
                            isFirstInSource: isFirstInSource(index),
                            isActive: segment.id == activeSegmentID,
                            opacity: opacity(for: index, segment: segment)
                        )
                        .id(segment.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSeek(segment)
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 46)
                .padding(.bottom, 80)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .background(lyricsBackground)
            .onChange(of: activeSegmentID) { _, newValue in
                guard let newValue else { return }

                withAnimation(.smooth(duration: 0.32)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    private func isFirstInSource(_ index: Int) -> Bool {
        guard let sourceName = segments[index].sourceName else {
            return index == 0
        }

        if index == 0 {
            return true
        }

        return segments[index - 1].sourceName != sourceName
    }

    private func opacity(for index: Int, segment: TranscriptSegment) -> Double {
        if segment.id == activeSegmentID {
            return 1
        }

        return max(0.34, 1 - Double(index) * 0.075)
    }

    private var lyricsBackground: some View {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.10),
                Color.clear,
                Color.black.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct LyricsLineView: View {
    let segment: TranscriptSegment
    let isFirstInSource: Bool
    let isActive: Bool
    let opacity: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isFirstInSource, let sourceName = segment.sourceName {
                Label(sourceName, systemImage: "waveform")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }

            HStack(alignment: .firstTextBaseline, spacing: 14) {
                if let displayTime = segment.displayTime {
                    Text(displayTime)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 42, alignment: .leading)
                        .padding(.top, 8)
                }

                Text(segment.text)
                    .font(lyricsFont)
                    .fontWeight(.bold)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .foregroundStyle(.primary.opacity(opacity))
            .scaleEffect(isActive ? 1.035 : 1, anchor: .leading)
            .animation(.smooth(duration: 0.22), value: isActive)
        }
    }

    private var lyricsFont: Font {
#if os(macOS)
        .system(size: 34, weight: .bold, design: .default)
#else
        .system(size: 28, weight: .bold, design: .default)
#endif
    }
}

#Preview {
    ContentView()
}
