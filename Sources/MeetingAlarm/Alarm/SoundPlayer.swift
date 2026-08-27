import AppKit
import AVFoundation
import Foundation

/// Plays the alarm sound: bundled clips (e.g. Jewel Drop) via `AVAudioPlayer`, or macOS
/// system sounds via `NSSound`. Repeats with a configurable gap between plays.
@MainActor
final class SoundPlayer {
    private var sound: NSSound?
    private var player: AVAudioPlayer?
    private var repeatTask: Task<Void, Never>?
    private let log = Log.make("sound")

    func play(_ choice: SoundChoice?, volume: Double, repeatForever: Bool, gap: TimeInterval) {
        stop()
        guard let choice else { return }
        let level = Float(max(0, min(1, volume)))
        var clipDuration: TimeInterval = 1

        if let resource = choice.resourceName {
            guard let url = Bundle.main.url(forResource: resource, withExtension: "m4a"),
                  let player = try? AVAudioPlayer(contentsOf: url)
            else {
                log.error("missing bundled sound \(resource, privacy: .public)")
                return
            }
            player.volume = level
            player.play()
            self.player = player
            clipDuration = player.duration
        } else if let name = choice.systemSoundName, let sound = NSSound(named: name) {
            sound.volume = level
            sound.play()
            self.sound = sound
            clipDuration = sound.duration
        } else {
            return
        }

        guard repeatForever else { return }
        let period = max(0.2, clipDuration + gap)
        repeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(period))
                guard !Task.isCancelled else { break }
                self?.replay()
            }
        }
    }

    private func replay() {
        if let player {
            player.currentTime = 0
            player.play()
        } else if let sound {
            sound.stop()
            sound.play()
        }
    }

    func stop() {
        repeatTask?.cancel()
        repeatTask = nil
        sound?.stop()
        sound = nil
        player?.stop()
        player = nil
    }
}
