import Foundation

enum TranscriptionChunker {
    nonisolated static let sampleRate = 16_000

    enum DecodingError: LocalizedError {
        case unreliableOutput(TimeInterval)

        var errorDescription: String? {
            switch self {
            case .unreliableOutput(let time):
                let seconds = Int(time)
                let timestamp = String(format: "%d:%02d", seconds / 60, seconds % 60)
                return "Whisper produced unreliable repeated text near \(timestamp), even after retrying. Try another model or select the spoken language."
            }
        }
    }

    nonisolated static func transcribe(
        samples: [Float],
        decode: ([Float], Int) throws -> [TranscriptSegment]
    ) throws -> [TranscriptSegment] {
        try process(samples: samples, offset: 0, level: 0, decode: decode)
    }

    nonisolated private static func process(
        samples: [Float],
        offset: TimeInterval,
        level: Int,
        decode: ([Float], Int) throws -> [TranscriptSegment]
    ) throws -> [TranscriptSegment] {
        let limit = [60, 15, 5][level] * sampleRate
        var cursor = 0
        var result: [TranscriptSegment] = []

        while cursor < samples.count {
            try Task.checkCancellation()
            let end = nextBoundary(in: samples, start: cursor, limit: limit)
            let range = cursor..<end
            defer { cursor = end }

            // Only trim near-digital silence, not quiet speech or background recordings.
            guard let active = activeRange(in: samples, range: range) else { continue }
            let chunk = Array(samples[active])
            let chunkOffset = offset + Double(active.lowerBound) / Double(sampleRate)
            let duration = Double(chunk.count) / Double(sampleRate)
            let decoded = try decode(chunk, level)

            if isRepetitive(decoded) || !hasValidTimes(decoded) {
                guard level < 2 else { throw DecodingError.unreliableOutput(chunkOffset) }
                result += try process(samples: chunk, offset: chunkOffset, level: level + 1, decode: decode)
                continue
            }

            for segment in decoded {
                guard let start = segment.startTime, let end = segment.endTime,
                      start < duration else { continue }
                let localStart = max(0, start)
                let localEnd = min(duration, max(end, localStart + 0.02))
                let sampleStart = min(chunk.count, Int(localStart * Double(sampleRate)))
                let sampleEnd = min(chunk.count, Int(localEnd * Double(sampleRate)))
                guard activeRange(in: chunk, range: sampleStart..<sampleEnd) != nil else { continue }

                result.append(TranscriptSegment(
                    text: segment.text,
                    startTime: chunkOffset + localStart,
                    endTime: chunkOffset + localEnd,
                    sourceName: nil
                ))
            }
        }

        return result
    }

    nonisolated static func nextBoundary(in samples: [Float], start: Int, limit: Int) -> Int {
        let end = min(samples.count, start + limit)
        let frame = sampleRate / 10
        var heardSignal = false
        var silentFrames = 0
        if end - start >= frame {
            // Whisper can place speech too early after a long empty gap. Decode utterances separately.
            for frameStart in stride(from: start, through: end - frame, by: frame) {
                let hasSignal = samples[frameStart..<(frameStart + frame)].contains { abs($0) > 0.000001 }
                if hasSignal {
                    heardSignal = true
                    silentFrames = 0
                } else if heardSignal {
                    silentFrames += 1
                    if silentFrames >= 8 {
                        return frameStart + frame - silentFrames * frame / 2
                    }
                }
            }
        }
        guard end < samples.count else { return end }

        // Prefer a quiet 100 ms gap near the end without dropping or overlapping samples.
        let searchStart = max(start + limit / 2, end - 5 * sampleRate)
        var bestEnd = end
        var bestEnergy = Float.infinity
        for frameStart in stride(from: end - frame, through: searchStart, by: -frame) {
            var energy: Float = 0
            for sample in samples[frameStart..<(frameStart + frame)] {
                energy += sample * sample
            }
            if energy < bestEnergy {
                bestEnergy = energy
                bestEnd = frameStart + frame / 2
            }
        }
        return bestEnd
    }

    nonisolated static func activeRange(in samples: [Float], range: Range<Int>) -> Range<Int>? {
        let signal = samples[range]
        guard let first = signal.firstIndex(where: { abs($0) > 0.000001 }),
              let last = signal.lastIndex(where: { abs($0) > 0.000001 }) else { return nil }
        let padding = sampleRate / 4
        return max(range.lowerBound, first - padding)..<min(range.upperBound, last + 1 + padding)
    }

    nonisolated static func isRepetitive(_ segments: [TranscriptSegment]) -> Bool {
        var previous = ""
        var run = 0
        for segment in segments {
            let normalized = String(segment.text.lowercased().unicodeScalars.filter {
                CharacterSet.alphanumerics.contains($0)
            })
            run = normalized == previous ? run + 1 : 1
            previous = normalized
            if normalized.count >= 8 && run >= 3 { return true }
        }

        let text = segments.map(\.text).joined(separator: " ")
        guard text.count >= 120 else { return false }
        let data = Data(text.utf8)
        guard let compressed = try? (data as NSData).compressed(using: .zlib), compressed.length > 0 else {
            return false
        }
        return Double(data.count) / Double(compressed.length) > 3
    }

    nonisolated private static func hasValidTimes(_ segments: [TranscriptSegment]) -> Bool {
        var previousStart: Double = -1
        for segment in segments {
            guard let start = segment.startTime, let end = segment.endTime,
                  start.isFinite, end.isFinite, start >= 0, end >= start,
                  start >= previousStart else { return false }
            previousStart = start
        }
        return true
    }
}
