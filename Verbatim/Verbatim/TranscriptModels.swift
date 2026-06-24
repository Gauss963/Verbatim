import Foundation
import SwiftUI

struct TranscriptionResult {
    var text: String {
        segments.map(\.text).joined(separator: "\n")
    }

    let segments: [TranscriptSegment]
}

struct TranscriptSegment: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let startTime: TimeInterval?
    let endTime: TimeInterval?
    var sourceName: String?
    var sourceURL: URL?

    var displayTime: String? {
        guard let startTime else { return nil }

        let totalSeconds = Int(startTime.rounded(.down))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

enum TranscriptLanguage: String, CaseIterable, Identifiable {
    case automatic
    case chinese
    case english

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:
            return "Auto"
        case .chinese:
            return "中文"
        case .english:
            return "English"
        }
    }

    nonisolated var whisperCode: String? {
        switch self {
        case .automatic:
            return nil
        case .chinese:
            return "zh"
        case .english:
            return "en"
        }
    }
}

enum WhisperModel: String, CaseIterable, Identifiable {
    case base = "ggml-base"
    case small = "ggml-small"
    case largeV3 = "ggml-large-v3"

    var id: String { rawValue }

    static var defaultModel: WhisperModel {
#if os(macOS)
        .largeV3
#else
        .small
#endif
    }

    var resourceName: String {
        rawValue
    }

    var title: String {
        switch self {
        case .base:
            return "Base"
        case .small:
            return "Small"
        case .largeV3:
            return "Large v3"
        }
    }

    var shortDetail: String {
        switch self {
        case .base:
            return "Fastest for iPhone and iPad"
        case .small:
            return "Balanced mobile model"
        case .largeV3:
            return "Best accuracy"
        }
    }
}

struct TranscriptFile: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var state: TranscriptFileState = .queued

    var iconName: String {
        switch url.pathExtension.lowercased() {
        case "mp4", "mov":
            return "film"
        default:
            return "waveform"
        }
    }

    var statusText: String {
        switch state {
        case .queued:
            return "Queued"
        case .running:
            return "Transcribing"
        case .finished:
            return "Done"
        case .failed(let message):
            return message.isEmpty ? "Failed" : message
        }
    }

    var statusTint: Color {
        switch state {
        case .queued:
            return .secondary
        case .running:
            return .accentColor
        case .finished:
            return .green
        case .failed:
            return .red
        }
    }
}

enum TranscriptFileState: Equatable {
    case queued
    case running
    case finished
    case failed(String)
}

struct EnvironmentStatus {
    let icon: String
    let message: String
    let tint: Color
}
