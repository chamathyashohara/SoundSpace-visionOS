import Foundation
import RealityKit

/// Loads every sound once at start, so strikes play with no delay.
@MainActor
final class SoundBank {
    private var resources: [String: AudioFileResource] = [:]

    func preload() {
        for instrument in Instrument.all {
            for (zone, file) in instrument.soundFiles.enumerated() {
                do {
                    resources[Instrument.key(instrument.id, zone: zone)] = try AudioFileResource.load(named: "\(file).wav")
                } catch {
                    print("Could not load sound \(file): \(error)")
                }
            }
        }
    }

    func resource(forKey key: String) -> AudioFileResource? { resources[key] }
    var loadedCount: Int { resources.count }
}
