#if os(iOS)
import Foundation
import AVFoundation
import Observation
import UIKit

// MARK: - Ambiance Service

@MainActor
@Observable
final class AmbianceService {
    static let shared = AmbianceService()

    var isPlaying: Bool = false
    var currentSound: String? = nil
    var volume: Double = 0.5

    private var audioPlayer: AVAudioPlayer?

    static let availableSounds: [(id: String, label: String, icon: String)] = [
        ("rain", "Rain", "cloud.rain.fill"),
        ("fireplace", "Fire", "flame.fill"),
        ("lofi", "Lo-Fi", "headphones"),
        ("forest", "Forest", "leaf.fill"),
        ("ocean", "Ocean", "water.waves"),
    ]

    private init() {
        // Stop audio when app enters background
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.stop()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Playback

    func play(_ sound: String) {
        // Stop current playback first
        stop()

        // Try to load bundled audio file
        let extensions = ["mp3", "m4a", "wav", "aac"]
        var url: URL?

        for ext in extensions {
            if let bundleURL = Bundle.main.url(forResource: sound, withExtension: ext) {
                url = bundleURL
                break
            }
        }

        guard let fileURL = url else {
            // Sound pack not installed - file not found in bundle
            currentSound = sound
            isPlaying = false
            return
        }

        do {
            // Configure audio session for ambient playback
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = Float(volume)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            currentSound = sound
            isPlaying = true
        } catch {
            currentSound = nil
            isPlaying = false
        }
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentSound = nil
    }

    func setVolume(_ vol: Double) {
        volume = max(0, min(1, vol))
        audioPlayer?.volume = Float(volume)
    }

    func toggle(_ sound: String) {
        if currentSound == sound && isPlaying {
            stop()
        } else {
            play(sound)
        }
    }

    /// Whether the given sound file is bundled with the app
    func isSoundAvailable(_ sound: String) -> Bool {
        let extensions = ["mp3", "m4a", "wav", "aac"]
        for ext in extensions {
            if Bundle.main.url(forResource: sound, withExtension: ext) != nil {
                return true
            }
        }
        return false
    }
}
#endif
