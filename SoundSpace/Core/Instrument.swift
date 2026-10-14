import Foundation
import simd

/// A virtual instrument in the studio. Pure data, so it can be unit tested without RealityKit.
struct Instrument: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    /// One sound file per playable zone (e.g. the two drums of the thammattama, or three chime bells).
    let soundFiles: [String]
    /// Default position in metres, relative to the floor below the user. Negative z is in front of you.
    let home: SIMD3<Float>
    /// True for the synth: its zones are chord pads, and the sound of each pad comes from the current chord progression.
    var chordPads = false

    var zoneCount: Int { soundFiles.count }

    /// Key used by the loop recorder and lessons to identify one playable zone.
    static func key(_ instrumentID: String, zone: Int) -> String { "\(instrumentID)#\(zone)" }

    static let getaBera = Instrument(id: "getabera", name: "Geta Bera", subtitle: "Two-headed Kandyan drum",
                                     soundFiles: ["getabera"], home: [-0.55, 1.0, -0.95])
    static let thammattama = Instrument(id: "thammattama", name: "Thammattama", subtitle: "Twin drums played with sticks",
                                        soundFiles: ["thammattama_high", "thammattama_low"], home: [0.0, 0.95, -1.05])
    static let rabana = Instrument(id: "rabana", name: "Rabana", subtitle: "Large frame drum",
                                   soundFiles: ["rabana"], home: [0.6, 1.0, -0.9])
    static let chimes = Instrument(id: "chimes", name: "Chimes", subtitle: "Melodic bells",
                                   soundFiles: ["chime_1", "chime_2", "chime_3"], home: [0.0, 1.45, -1.2])

    /// The drum kit: kick, snare, hi-hat, tom and crash cymbal in one group.
    static let drumKit = Instrument(id: "drumkit", name: "Drum Kit", subtitle: "Kick, snare, hi-hat, tom and crash",
                                    soundFiles: ["kick", "snare", "hihat", "tom", "crash"], home: [0.0, 0.85, -0.9])
    /// The chord synth: four pads, one per chord of the progression.
    static let chordSynth = Instrument(id: "chordpads", name: "Chord Synth", subtitle: "Four pads play your chord progression",
                                       soundFiles: ["", "", "", ""], home: [0.0, 1.5, -1.15], chordPads: true)

    static let traditional: [Instrument] = [getaBera, thammattama, rabana, chimes]
    static let band: [Instrument] = [drumKit, chordSynth]
    static let all: [Instrument] = traditional + band

    /// Names for the drum kit zones, in zone order.
    static let drumKitZoneNames = ["Kick", "Snare", "Hi-hat", "Tom", "Crash"]

    static func named(_ id: String) -> Instrument? { all.first { $0.id == id } }

    /// Display name for a loop / lesson key such as "thammattama#1".
    static func displayName(forKey key: String) -> String {
        let id = key.split(separator: "#").first.map(String.init) ?? key
        if id == drumKit.id, let zone = key.split(separator: "#").last.flatMap({ Int($0) }), zone < drumKitZoneNames.count {
            return drumKitZoneNames[zone]
        }
        return named(id)?.name ?? key
    }
}

/// Where instruments may be dragged to. Keeps everything within comfortable arm's reach (visionOS design guidance).
enum StudioBounds {
    static let x: ClosedRange<Float> = -1.2...1.2
    static let y: ClosedRange<Float> = 0.5...1.8
    static let z: ClosedRange<Float> = -1.6 ... -0.35

    static func clamp(_ p: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3(min(max(p.x, x.lowerBound), x.upperBound),
              min(max(p.y, y.lowerBound), y.upperBound),
              min(max(p.z, z.lowerBound), z.upperBound))
    }
}
