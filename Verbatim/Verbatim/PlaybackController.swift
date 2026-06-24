import AVFoundation
import Foundation
import Observation

@Observable
final class PlaybackController {
    var currentURL: URL?
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var isPlaying = false

    let player = AVPlayer()
    private var timeObserver: Any?
    private var durationObserver: NSKeyValueObservation?
    private var statusObserver: NSKeyValueObservation?
    private var scopedURL: URL?
    private var isAccessingScopedResource = false

    init() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.08, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }

            self.currentTime = time.seconds.isFinite ? time.seconds : 0

            if let itemDuration = self.player.currentItem?.duration.seconds, itemDuration.isFinite {
                self.duration = itemDuration
            }

            self.isPlaying = self.player.timeControlStatus == .playing
        }
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }

        stopAccessingScopedResource()
    }

    func prepare(url: URL) {
        guard currentURL != url else { return }

        configureAudioSession()
        stopAccessingScopedResource()
        scopedURL = url
        isAccessingScopedResource = url.startAccessingSecurityScopedResource()

        currentURL = url
        currentTime = 0
        duration = 0
        isPlaying = false

        let item = AVPlayerItem(url: url)
        observe(item)
        player.replaceCurrentItem(with: item)
    }

    func reset() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        durationObserver = nil
        statusObserver = nil
        currentURL = nil
        currentTime = 0
        duration = 0
        isPlaying = false
        stopAccessingScopedResource()
    }

    func togglePlayPause() {
        guard player.currentItem != nil else { return }

        if player.timeControlStatus == .playing {
            player.pause()
            isPlaying = false
        } else {
            configureAudioSession()
            player.play()
            isPlaying = true
        }
    }

    func seek(to seconds: TimeInterval, play: Bool = false) {
        guard player.currentItem != nil else { return }

        let clamped = max(0, min(seconds, duration > 0 ? duration : seconds))
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = clamped

        if play {
            configureAudioSession()
            player.play()
            isPlaying = true
        }
    }

    private func observe(_ item: AVPlayerItem) {
        durationObserver = item.observe(\.duration, options: [.initial, .new]) { [weak self] item, _ in
            guard let self else { return }

            Task { @MainActor in
                let seconds = item.duration.seconds
                self.duration = seconds.isFinite ? max(0, seconds) : 0
            }
        }

        statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self else { return }

            Task { @MainActor in
                if item.status == .failed {
                    self.isPlaying = false
                }
            }
        }
    }

    private func stopAccessingScopedResource() {
        if isAccessingScopedResource {
            scopedURL?.stopAccessingSecurityScopedResource()
        }

        scopedURL = nil
        isAccessingScopedResource = false
    }

    private func configureAudioSession() {
#if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            assertionFailure("Could not configure audio session: \(error.localizedDescription)")
        }
#endif
    }
}
