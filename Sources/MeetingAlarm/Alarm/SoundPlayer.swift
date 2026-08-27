import AppKit
import AVFoundation

/// Plays the alarm sound: bundled clips (e.g. Jewel Drop) via `AVAudioPlayer` with looping,
/// or macOS system sounds via `NSSound`. `nil` choice is silent.
@MainActor
final class SoundPlayer {
    private var sound: NSSound?
    private var player: AVAudioPlayer?
    private let log = Log.make("sound")

    func play(_ choice: SoundChoice?, volume: Double, repeats: Bool) {
        stop()
        guard let choice else { return }
        let level = Float(max(0, min(1, volume)))

        if let resource = choice.resourceName {
            guard let url = Bundle.main.url(forResource: resource, withExtension: "m4a"),
                  let player = try? AVAudioPlayer(contentsOf: url)
            else {
                log.error("missing bundled sound \(resource, privacy: .public)")
                return
            }
            player.volume = level
            player.numberOfLoops = repeats ? -1 : 0
            player.play()
            self.player = player
        } else if let name = choice.systemSoundName, let sound = NSSound(named: name) {
            sound.volume = level
            sound.loops = repeats
            sound.play()
            self.sound = sound
        }
    }

    func stop() {
        sound?.stop()
        sound = nil
        player?.stop()
        player = nil
    }
}
