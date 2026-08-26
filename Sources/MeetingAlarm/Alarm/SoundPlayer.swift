import AppKit

/// Optional alarm audio. Uses macOS system sounds so no asset bundling is needed for v1.
@MainActor
final class SoundPlayer {
    private var sound: NSSound?
    private let log = Log.make("sound")

    func play(_ choice: SoundChoice?, volume: Double, repeats: Bool) {
        stop()
        guard let choice else { return }
        let name: NSSound.Name = switch choice {
        case .chime: "Glass"
        case .alarm: "Sosumi"
        case .ping: "Ping"
        }
        guard let sound = NSSound(named: name) else {
            log.error("missing system sound \(name, privacy: .public)")
            return
        }
        sound.volume = Float(max(0, min(1, volume)))
        sound.loops = repeats
        self.sound = sound
        sound.play()
    }

    func stop() {
        sound?.stop()
        sound = nil
    }
}
