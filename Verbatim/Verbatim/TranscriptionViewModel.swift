import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers

@Observable
final class TranscriptionViewModel {
    var files: [TranscriptFile] = []
    var language: TranscriptLanguage = .automatic
    var selectedModel: WhisperModel = .defaultModel {
        didSet {
            refreshEnvironmentStatus()
        }
    }
    var transcript = ""
    var transcriptSegments: [TranscriptSegment] = []
    var isTranscribing = false
    var environmentStatus: EnvironmentStatus?
    let playback = PlaybackController()

    private let transcriber = WhisperTranscriber()

    var completedFileCount: Int {
        files.filter { file in
            if case .finished = file.state {
                return true
            }

            return false
        }.count
    }

    var processedFileCount: Int {
        files.filter { file in
            switch file.state {
            case .finished, .failed:
                return true
            case .queued, .running:
                return false
            }
        }.count
    }

    var progressFraction: Double {
        guard !files.isEmpty else { return 0 }
        return Double(processedFileCount) / Double(files.count)
    }

    var progressTitle: String {
        if files.isEmpty {
            return "No files queued"
        }

        if isTranscribing {
            return "Transcribing \(processedFileCount + 1) of \(files.count)"
        }

        if processedFileCount == files.count, !files.isEmpty {
            return "Finished \(completedFileCount) of \(files.count)"
        }

        return "\(files.count) file\(files.count == 1 ? "" : "s") ready"
    }

    var currentFileName: String? {
        files.first { file in
            if case .running = file.state {
                return true
            }

            return false
        }?.url.lastPathComponent
    }

    var outputSubtitle: String {
        if isTranscribing {
            if let currentFileName {
                return "Running Whisper \(selectedModel.title) on \(currentFileName)"
            }

            return "Running Whisper \(selectedModel.title) locally"
        }

        if files.isEmpty {
            return "Ready for local audio and video files"
        }

        return "\(files.count) file\(files.count == 1 ? "" : "s") queued"
    }

    var playbackTitle: String {
        guard let currentURL = playback.currentURL else {
            return "No playable transcript yet"
        }

        return currentURL.lastPathComponent
    }

    var playbackShowsVideo: Bool {
        guard let currentURL = playback.currentURL else { return false }

        return ["mp4", "mov", "m4v"].contains(currentURL.pathExtension.lowercased())
    }

    var activeSegmentID: UUID? {
        guard let currentURL = playback.currentURL else { return nil }

        let currentTime = playback.currentTime
        return transcriptSegments.last { segment in
            guard segment.sourceURL == currentURL, let startTime = segment.startTime else {
                return false
            }

            let endTime = segment.endTime ?? startTime
            return currentTime >= startTime && currentTime < max(endTime, startTime + 0.35)
        }?.id
    }

    func refreshEnvironmentStatus() {
        environmentStatus = transcriber.environmentStatus(for: selectedModel)
    }

    func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
                guard let self, let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }

                Task { @MainActor in
                    self.addFiles([url])
                }
            }
        }

        return true
    }

    func addFiles(_ urls: [URL]) {
        let supportedExtensions = Set(["mp3", "mp4", "m4a", "wav", "aiff", "aif", "mov", "aac", "flac"])
        let newFiles = urls
            .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
            .filter { candidate in !files.contains { $0.url == candidate } }
            .map { TranscriptFile(url: $0) }

        files.append(contentsOf: newFiles)
        refreshEnvironmentStatus()
    }

    func remove(_ file: TranscriptFile) {
        files.removeAll { $0.id == file.id }
    }

    func transcribeSelectedFiles() async {
        guard !files.isEmpty, !isTranscribing else { return }

        refreshEnvironmentStatus()
        isTranscribing = true
        playback.reset()
        transcript = ""
        transcriptSegments = []

        for index in files.indices {
            if files[index].state != .queued {
                files[index].state = .queued
            }
        }

        for index in files.indices {
            files[index].state = .running

            do {
                let result = try await transcriber.transcribe(url: files[index].url, language: language, model: selectedModel)
                files[index].state = .finished
                append(result, sourceURL: files[index].url)
            } catch {
                files[index].state = .failed(error.localizedDescription)
                append(errorMessage: error.localizedDescription, sourceURL: files[index].url)
            }
        }

        isTranscribing = false
        refreshEnvironmentStatus()
    }

    func playPauseTranscript() {
        guard playback.currentURL != nil else {
            if let firstPlayableURL = transcriptSegments.first(where: { $0.sourceURL != nil })?.sourceURL {
                playback.prepare(url: firstPlayableURL)
                playback.togglePlayPause()
            }

            return
        }

        playback.togglePlayPause()
    }

    func seek(to segment: TranscriptSegment) {
        guard let sourceURL = segment.sourceURL, let startTime = segment.startTime else { return }

        playback.prepare(url: sourceURL)
        playback.seek(to: startTime, play: true)
    }

    func seekPlayback(to fraction: Double) {
        guard playback.duration > 0 else { return }

        playback.seek(to: playback.duration * max(0, min(1, fraction)))
    }

    private func append(_ result: TranscriptionResult, sourceURL: URL) {
        let sourceName = sourceURL.lastPathComponent
        let trimmed = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let section = """

        \(sourceName)
        \(String(repeating: "-", count: sourceName.count))
        \(trimmed)

        """

        transcript += section
        transcriptSegments += result.segments.map { segment in
            TranscriptSegment(
                text: segment.text,
                startTime: segment.startTime,
                endTime: segment.endTime,
                sourceName: sourceName,
                sourceURL: sourceURL
            )
        }

        if playback.currentURL == nil {
            playback.prepare(url: sourceURL)
        }
    }

    private func append(errorMessage: String, sourceURL: URL) {
        let sourceName = sourceURL.lastPathComponent
        let message = "Failed: \(errorMessage)"
        let section = """

        \(sourceName)
        \(String(repeating: "-", count: sourceName.count))
        \(message)

        """

        transcript += section
        transcriptSegments.append(
            TranscriptSegment(
                text: message,
                startTime: nil,
                endTime: nil,
                sourceName: sourceName,
                sourceURL: sourceURL
            )
        )
    }
}
