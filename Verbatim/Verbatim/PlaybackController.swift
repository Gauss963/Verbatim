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
    }

    func prepare(url: URL) {
        guard currentURL != url else { return }

        currentURL = url
        currentTime = 0
        duration = 0
        isPlaying = false
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
    }

    func reset() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentURL = nil
        currentTime = 0
        duration = 0
        isPlaying = false
    }

    func togglePlayPause() {
        guard player.currentItem != nil else { return }

        if player.timeControlStatus == .playing {
            player.pause()
            isPlaying = false
        } else {
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
            player.play()
            isPlaying = true
        }
    }
}
