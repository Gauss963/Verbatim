import AVFoundation
import Foundation

struct AudioSampleDecoder {
    func decode(url: URL) async throws -> [Float] {
        try await Task.detached(priority: .userInitiated) {
            let asset = AVURLAsset(url: url)
            guard let track = asset.tracks(withMediaType: .audio).first else {
                throw TranscriptionError.noAudioTrack
            }

            let reader = try AVAssetReader(asset: asset)
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
            output.alwaysCopiesSampleData = false

            guard reader.canAdd(output) else {
                throw TranscriptionError.unsupportedMedia
            }

            reader.add(output)
            guard reader.startReading() else {
                throw reader.error ?? TranscriptionError.unsupportedMedia
            }

            var samples: [Float] = []
            while let sampleBuffer = output.copyNextSampleBuffer() {
                guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
                    continue
                }

                let length = CMBlockBufferGetDataLength(blockBuffer)
                guard length > 0 else {
                    continue
                }

                let sampleCount = length / MemoryLayout<Float>.size
                let startIndex = samples.count
                samples.append(contentsOf: repeatElement(0, count: sampleCount))

                samples.withUnsafeMutableBytes { rawBuffer in
                    guard let destination = rawBuffer.baseAddress?.advanced(by: startIndex * MemoryLayout<Float>.size) else {
                        return
                    }

                    CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: destination)
                }
            }

            if reader.status == .failed {
                throw reader.error ?? TranscriptionError.unsupportedMedia
            }

            return samples
        }.value
    }
}
