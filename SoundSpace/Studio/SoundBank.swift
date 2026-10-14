import Foundation
import RealityKit

/// Loads every sound once at start, so strikes play with no delay.
@MainActor
final class SoundBank {
    private var resources: [String: AudioFileResource] = [:]
    private var chordResources: [String: AudioFileResource] = [:]

    func preload() {
        for instrument in Instrument.all where !instrument.chordPads {
            for (zone, file) in instrument.soundFiles.enumerated() {
                do {
                    resources[Instrument.key(instrument.id, zone: zone)] = try AudioFileResource.load(named: "\(file).wav")
                } catch {
                    print("Could not load sound \(file): \(error)")
                }
            }
        }
        // All 24 chords (12 roots x major / minor), so changing key or progression never waits for a file.
        for root in 0..<12 {
            for quality in [ChordQuality.major, .minor] {
                let chord = Chord(root: root, quality: quality)
                do {
                    chordResources[chord.soundFile] = try AudioFileResource.load(named: "\(chord.soundFile).wav")
                } catch {
                    print("Could not load chord \(chord.soundFile): \(error)")
                }
            }
        }
    }

    func resource(forKey key: String) -> AudioFileResource? { resources[key] }
    func resource(for chord: Chord) -> AudioFileResource? { chordResources[chord.soundFile] }
    var loadedCount: Int { resources.count + chordResources.count }
}
