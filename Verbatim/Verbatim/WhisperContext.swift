import Foundation
import whisper

enum WhisperError: LocalizedError {
    case couldNotInitializeContext
    case transcriptionFailed

    var errorDescription: String? {
        switch self {
        case .couldNotInitializeContext:
            return "Could not initialize Whisper large-v3."
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

        guard let context = whisper_init_from_file_with_params(path, params) else {
            throw WhisperError.couldNotInitializeContext
        }

        self.context = context
    }

    deinit {
        whisper_free(context)
    }

    func transcribe(samples: [Float], language: TranscriptLanguage) throws -> TranscriptionResult {
        let maxThreads = max(1, min(8, ProcessInfo.processInfo.processorCount - 2))
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_realtime = false
        params.print_progress = false
        params.print_timestamps = false
        params.print_special = false
        params.translate = false
        params.n_threads = Int32(maxThreads)
        params.offset_ms = 0
        params.no_context = true
        params.single_segment = false

        let result: Int32
        if let whisperCode = language.whisperCode {
            result = whisperCode.withCString { code in
                params.language = code
                return runFullTranscription(params: params, samples: samples)
            }
        } else {
            result = runFullTranscription(params: params, samples: samples)
        }

        guard result == 0 else {
            throw WhisperError.transcriptionFailed
        }

        var segments: [TranscriptSegment] = []
        for index in 0..<whisper_full_n_segments(context) {
            let text = String(cString: whisper_full_get_segment_text(context, index))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else { continue }

            segments.append(
                TranscriptSegment(
                    text: text,
                    startTime: TimeInterval(whisper_full_get_segment_t0(context, index)) / 100,
                    endTime: TimeInterval(whisper_full_get_segment_t1(context, index)) / 100,
                    sourceName: nil
                )
            )
        }

        return TranscriptionResult(segments: segments)
    }

    private func runFullTranscription(params: whisper_full_params, samples: [Float]) -> Int32 {
        whisper_reset_timings(context)
        return samples.withUnsafeBufferPointer { buffer in
            whisper_full(context, params, buffer.baseAddress, Int32(samples.count))
        }
    }
}
