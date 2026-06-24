import Foundation
import SwiftUI

final class WhisperTranscriber {
    private let decoder = AudioSampleDecoder()
    private var contexts: [WhisperModel: WhisperContext] = [:]

    private func modelURL(for model: WhisperModel) -> URL? {
        Bundle.main.url(forResource: model.resourceName, withExtension: "bin", subdirectory: "models")
            ?? Bundle.main.url(forResource: model.resourceName, withExtension: "bin")
    }

    func environmentStatus(for model: WhisperModel) -> EnvironmentStatus {
        guard let modelURL = modelURL(for: model), FileManager.default.fileExists(atPath: modelURL.path) else {
            return EnvironmentStatus(icon: "arrow.down.circle", message: "Bundled Whisper \(model.title) model is missing.", tint: .orange)
        }

        return EnvironmentStatus(icon: "checkmark.circle", message: "Bundled Whisper \(model.title) is ready.", tint: .green)
    }

    func transcribe(url: URL, language: TranscriptLanguage, model: WhisperModel) async throws -> TranscriptionResult {
        guard let modelURL = modelURL(for: model) else {
            throw TranscriptionError.missingBundledModel(model.title)
        }

        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let activeContext: WhisperContext
        if let context = contexts[model] {
            activeContext = context
        } else {
            activeContext = try WhisperContext(path: modelURL.path)
            contexts[model] = activeContext
        }

        let samples = try await decoder.decode(url: url)
        guard !samples.isEmpty else {
            throw TranscriptionError.noAudioSamples
        }

        return try await activeContext.transcribe(samples: samples, language: language)
    }
}

enum TranscriptionError: LocalizedError {
    case missingBundledModel(String)
    case noAudioTrack
    case noAudioSamples
    case unsupportedMedia

    var errorDescription: String? {
        switch self {
        case .missingBundledModel(let modelName):
            return "The bundled Whisper \(modelName) model was not found."
        case .noAudioTrack:
            return "This file does not contain an audio track."
        case .noAudioSamples:
            return "No readable audio samples were decoded."
        case .unsupportedMedia:
            return "This media file is not supported by AVFoundation."
        }
    }
}
