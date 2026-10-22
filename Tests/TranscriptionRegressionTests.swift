import AVFoundation
import Foundation
import whisper

@main
struct TranscriptionRegressionTests {
    static func main() async throws {
        try testDecodingParameters()
        try testChunkCoverage()
        try testSilenceAndQuietAudio()
        try testRecoveryAndTimestamps()
        try testBoundedFailure()
        try testRealRepeatedSpeechIsPreserved()
        print("PASS: 6 transcription regression tests")

        if CommandLine.arguments.contains("--integration") {
            let root = URL(fileURLWithPath: CommandLine.arguments[1])
            try await testLongRecording(root: root)
        }
    }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw TestFailure(message: message) }
    }

    static func segment(_ text: String, start: Double = 0, end: Double = 1) -> TranscriptSegment {
        TranscriptSegment(text: text, startTime: start, endTime: end, sourceName: nil)
    }

    static func testDecodingParameters() throws {
        for level in 0...2 {
            let params = WhisperContext.decodingParameters(recoveryLevel: level)
            try expect(params.no_context && params.n_max_text_ctx == 0, "History must be disabled inside each Whisper window")
            try expect(params.language == nil, "Automatic language must not default to English")
        }
    }

    static func testChunkCoverage() throws {
        let count = 31 * 60 * TranscriptionChunker.sampleRate + 137
        let samples = [Float](repeating: 0, count: count)
        var cursor = 0
        var chunks = 0
        while cursor < count {
            let end = TranscriptionChunker.nextBoundary(in: samples, start: cursor, limit: 60 * 16_000)
            try expect(end > cursor && end <= min(count, cursor + 60 * 16_000), "Chunks must advance, cover the tail, and stay bounded")
            cursor = end
            chunks += 1
        }
        try expect(cursor == count && chunks > 30, "Must cover all samples beyond 30 minutes")
        var paused = [Float](repeating: 0, count: 10 * 16_000)
        paused.replaceSubrange(16_000..<32_000, with: repeatElement(Float(0.1), count: 16_000))
        paused.replaceSubrange(8 * 16_000..<9 * 16_000, with: repeatElement(Float(0.1), count: 16_000))
        let pauseBoundary = TranscriptionChunker.nextBoundary(in: paused, start: 0, limit: 60 * 16_000)
        try expect(pauseBoundary > 2 * 16_000 && pauseBoundary < 8 * 16_000, "A long silent gap must separate utterances")
    }

    static func testSilenceAndQuietAudio() throws {
        var calls = 0
        let silent = try TranscriptionChunker.transcribe(samples: [Float](repeating: 0, count: 16_000)) { _, _ in
            calls += 1
            return []
        }
        try expect(silent.isEmpty && calls == 0, "Digital silence must not be sent to the model")
        let quiet = try TranscriptionChunker.transcribe(samples: [Float](repeating: 0.00001, count: 16_000)) { _, _ in
            calls += 1
            return [segment("quiet speech")]
        }
        try expect(quiet.count == 1 && calls == 1, "Quiet recordings must not be treated as silence")
    }

    static func testRecoveryAndTimestamps() throws {
        var levels: [Int] = []
        let result = try TranscriptionChunker.transcribe(samples: [Float](repeating: 0.1, count: 75 * 16_000)) { chunk, level in
            levels.append(level)
            if level == 0 {
                return (0..<3).map { segment("A repeated decoder sentence.", start: Double($0), end: Double($0 + 1)) }
            }
            return [segment("Recovered section", end: Double(chunk.count) / 16_000)]
        }
        try expect(levels.contains(1), "Repetition must trigger shorter independent decoding")
        try expect((result.last?.endTime ?? 0) == 75, "Recovered timestamps must reach the original file end")
        try expect(result.contains(where: { ($0.startTime ?? 0) > 60 }), "Recovery must preserve global time offsets")
        for pair in zip(result, result.dropFirst()) {
            try expect(pair.0.endTime! <= pair.1.startTime!, "Chunks must not overlap in the playback timeline")
        }
    }

    static func testBoundedFailure() throws {
        var calls = 0
        do {
            _ = try TranscriptionChunker.transcribe(samples: [Float](repeating: 0.1, count: 60 * 16_000)) { _, _ in
                calls += 1
                return [segment(String(repeating: "Endless repeated sentence. ", count: 30))]
            }
            throw TestFailure(message: "Persistent repetition must report an error, not be accepted")
        } catch TranscriptionChunker.DecodingError.unreliableOutput {
            try expect(calls == 3, "Retry depth must be bounded")
        }
    }

    static func testRealRepeatedSpeechIsPreserved() throws {
        let result = try TranscriptionChunker.transcribe(samples: [Float](repeating: 0.1, count: 120 * 16_000)) { chunk, _ in
            [segment("A genuine repeated chorus.", end: Double(chunk.count) / 16_000)]
        }
        try expect(result.count >= 2, "Do not globally deduplicate genuine repeated speech")
        try expect(!TranscriptionChunker.isRepetitive([segment("yes"), segment("yes"), segment("yes")]), "Short repeated words are not proof of a decoder loop")
        try expect(!TranscriptionChunker.isRepetitive([segment("A normal sentence.")]), "Normal text must not trigger recovery")
        try expect(TranscriptionChunker.isRepetitive([segment(String(repeating: "這是一段無限重複的中文句子。", count: 30))]), "Chinese repeated output must also trigger recovery")
    }

    static func testLongRecording(root: URL) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let markers: [(Double, String, String)] = [
            (3, "The first marker is a red bicycle near the river.", "bicycle"),
            (57, "The second marker is a green apple beside the window.", "apple"),
            (1_805, "After thirty minutes the final marker is a yellow submarine.", "submarine"),
            (1_840, "The recording ends with a purple umbrella and a silver telescope.", "telescope")
        ]
        var samples = [Float](repeating: 0, count: 31 * 60 * 16_000)
        let decoder = AudioSampleDecoder()
        for (index, marker) in markers.enumerated() {
            let audio = directory.appendingPathComponent("speech-\(index).aiff")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
            process.arguments = ["-v", "Samantha", "-o", audio.path, marker.1]
            try process.run()
            process.waitUntilExit()
            try expect(process.terminationStatus == 0, "Could not generate regression speech")
            let speech = try await decoder.decode(url: audio)
            let start = Int(marker.0 * 16_000)
            samples.replaceSubrange(start..<(start + speech.count), with: speech)
        }

        let longAudio = directory.appendingPathComponent("31-minute-recording.wav")
        let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            buffer.floatChannelData![0].update(from: source.baseAddress!, count: source.count)
        }
        do {
            let file = try AVAudioFile(forWriting: longAudio, settings: format.settings)
            try file.write(from: buffer)
        }
        let decoded = try await decoder.decode(url: longAudio)
        try expect(decoded.count == samples.count, "AVFoundation must decode the full 31-minute recording")

        let modelName = ProcessInfo.processInfo.environment["VERBATIM_TEST_MODEL"] ?? "base"
        try expect(["base", "small", "large-v3"].contains(modelName), "Unknown test model")
        let model = root.appendingPathComponent("Verbatim/Verbatim/models/ggml-\(modelName).bin")
        let context = try WhisperContext(path: model.path)
        let result = try await context.transcribe(samples: decoded, language: .english)
        for segment in result.segments {
            print("\(segment.startTime ?? -1)-\(segment.endTime ?? -1): \(segment.text)")
        }
        for (time, _, keyword) in markers {
            let match = result.segments.first { $0.text.lowercased().contains(keyword) }
            try expect(match != nil, "Missing spoken marker: \(keyword)")
            try expect(abs((match?.startTime ?? 0) - time) < 3, "Incorrect timestamp for \(keyword): \(match?.startTime ?? -1), expected \(time)")
        }
        try expect(!TranscriptionChunker.isRepetitive(result.segments), "Long-form output must not repeat indefinitely")
        print(result.text)
        print("PASS: real \(modelName) transcription of a 31-minute WAV, including speech near chunk boundaries and after 30:00")
    }
}

struct TestFailure: Error {
    let message: String
}
