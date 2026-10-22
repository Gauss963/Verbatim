import Foundation
import whisper

enum WhisperError: LocalizedError {
    case couldNotInitializeContext
    case transcriptionFailed

    var errorDescription: String? {
        switch self {
        case .couldNotInitializeContext:
            return "Could not initialize the Whisper model."
        case .transcriptionFailed:
            return "Whisper failed to transcribe this file."
        }
    }
}

actor WhisperContext {
    private let context: OpaquePointer

    init(path: String) throws {
        var params = whisper_context_default_params()
#if targetEnvironment(simulator)
        params.use_gpu = false
#else
        params.flash_attn = true
#endif

        guard let context = whisper_init_from_file_with_params_no_state(path, params) else {
            throw WhisperError.couldNotInitializeContext
        }

        self.context = context
    }

    deinit {
        whisper_free(context)
    }

    func transcribe(samples: [Float], language: TranscriptLanguage) throws -> TranscriptionResult {
        let segments = try TranscriptionChunker.transcribe(samples: samples) { chunk, level in
            try decodeChunk(samples: chunk, language: language, recoveryLevel: level)
        }
        return TranscriptionResult(segments: segments)
    }

    nonisolated static func decodingParameters(recoveryLevel: Int) -> whisper_full_params {
        let maxThreads = max(1, min(8, ProcessInfo.processInfo.processorCount - 2))
        let strategy = recoveryLevel == 1 ? WHISPER_SAMPLING_BEAM_SEARCH : WHISPER_SAMPLING_GREEDY
        var params = whisper_full_default_params(strategy)
        params.print_realtime = false
        params.print_progress = false
        params.print_timestamps = false
        params.print_special = false
        params.translate = false
        params.n_threads = Int32(maxThreads)
        params.offset_ms = 0
        params.no_context = true
        // no_context clears history at call entry only; this also disables history between windows.
        params.n_max_text_ctx = 0
        params.single_segment = false
        params.language = nil
        params.beam_search.beam_size = 5
        if recoveryLevel == 2 {
            params.temperature = 0.4
            params.greedy.best_of = 5
        }
        return params
    }

    private func decodeChunk(samples: [Float], language: TranscriptLanguage, recoveryLevel: Int) throws -> [TranscriptSegment] {
        guard let state = whisper_init_state(context) else {
            throw WhisperError.couldNotInitializeContext
        }
        defer { whisper_free_state(state) }

        var params = Self.decodingParameters(recoveryLevel: recoveryLevel)
        // Pad a very short final fragment without extending its reported timeline.
        let input = samples.count < TranscriptionChunker.sampleRate
            ? samples + Array(repeating: 0, count: TranscriptionChunker.sampleRate - samples.count)
            : samples

        let result = (language.whisperCode ?? "auto").withCString { code in
            params.language = code
            return input.withUnsafeBufferPointer { buffer in
                whisper_full_with_state(context, state, params, buffer.baseAddress, Int32(buffer.count))
            }
        }

        guard result == 0 else {
            throw WhisperError.transcriptionFailed
        }

        var segments: [TranscriptSegment] = []
        for index in 0..<whisper_full_n_segments_from_state(state) {
            let text = String(cString: whisper_full_get_segment_text_from_state(state, index))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else { continue }

            segments.append(
                TranscriptSegment(
                    text: text,
                    startTime: TimeInterval(whisper_full_get_segment_t0_from_state(state, index)) / 100,
                    endTime: TimeInterval(whisper_full_get_segment_t1_from_state(state, index)) / 100,
                    sourceName: nil
                )
            )
        }

        return segments
    }
}
