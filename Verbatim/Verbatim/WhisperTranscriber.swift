import Foundation
import SwiftUI

final class WhisperTranscriber {
    private let decoder = AudioSampleDecoder()
    private var context: WhisperContext?

    private var modelURL: URL? {
        Bundle.main.url(forResource: "ggml-large-v3", withExtension: "bin", subdirectory: "models")
            ?? Bundle.main.url(forResource: "ggml-large-v3", withExtension: "bin")
    }

    func environmentStatus() -> EnvironmentStatus {
        guard let modelURL, FileManager.default.fileExists(atPath: modelURL.path) else {
            return EnvironmentStatus(icon: "arrow.down.circle", message: "Bundled Whisper large-v3 model is missing.", tint: .orange)
        }

        return EnvironmentStatus(icon: "checkmark.circle", message: "Bundled Whisper large-v3 is ready.", tint: .green)
    }

    func transcribe(url: URL, language: TranscriptLanguage) async throws -> TranscriptionResult {
        guard let modelURL else {
            throw TranscriptionError.missingBundledModel
        }

        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let activeContext: WhisperContext
        if let context {
            activeContext = context
        } else {
            activeContext = try WhisperContext(path: modelURL.path)
            context = activeContext
        }

        let samples = try await decoder.decode(url: url)
        guard !samples.isEmpty else {
            throw TranscriptionError.noAudioSamples
        }

        return try await activeContext.transcribe(samples: samples, language: language)
    }
}

enum TranscriptionError: LocalizedError {
    case missingBundledModel
    case noAudioTrack
    case noAudioSamples
    case unsupportedMedia

    var errorDescription: String? {
        switch self {
        case .missingBundledModel:
            return "The bundled Whisper large-v3 model was not found."
        case .noAudioTrack:
            return "This file does not contain an audio track."
        case .noAudioSamples:
            return "No readable audio samples were decoded."
        case .unsupportedMedia:
            return "This media file is not supported by AVFoundation."
        }
    }
}
