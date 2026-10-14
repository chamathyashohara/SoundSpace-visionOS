import Foundation

enum ChordQuality: String {
    case major = "maj"
    case minor = "min"

    /// Semitones from the root to the third of the chord.
    var thirdInterval: Int { self == .major ? 4 : 3 }
}

/// A major or minor triad. Pure data, so it can be unit tested without any audio.
struct Chord: Hashable {
    static let noteNames = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]

    let root: Int            // pitch class, 0 = C ... 11 = B
    let quality: ChordQuality

    init(root: Int, quality: ChordQuality) {
        self.root = ((root % 12) + 12) % 12
        self.quality = quality
    }

    /// "C", "Am", "B♭" ...
    var name: String { Chord.noteNames[root] + (quality == .minor ? "m" : "") }

    /// Pre-rendered sound for this chord (made by scripts/make_sounds.py), e.g. "chord_9_min".
    var soundFile: String { "chord_\(root)_\(quality.rawValue)" }

    /// The three notes as pitch classes (root, third, fifth).
    var pitchClasses: [Int] { [root, (root + quality.thirdInterval) % 12, (root + 7) % 12] }
}

/// A four-chord loop in one major key, built from the six easiest chords of the key (I ii iii IV V vi).
/// Each slot stores a scale degree, so changing the key transposes the whole progression.
struct ChordProgression: Equatable {
    static let slotCount = 4
    static let degreeNames = ["I", "ii", "iii", "IV", "V", "vi"]
    private static let degreeOffsets = [0, 2, 4, 5, 7, 9]                 // semitones above the key note
    private static let degreeQualities: [ChordQuality] = [.major, .minor, .minor, .major, .major, .minor]

    var keyRoot: Int                     // pitch class of the key note, 0 = C
    var degrees: [Int]                   // four values in 0...5

    init(keyRoot: Int = 0, degrees: [Int] = [0, 4, 5, 3]) {
        self.keyRoot = ((keyRoot % 12) + 12) % 12
        var padded = degrees.prefix(ChordProgression.slotCount).map { min(max($0, 0), 5) }
        while padded.count < ChordProgression.slotCount { padded.append(0) }
        self.degrees = padded
    }

    func chord(at slot: Int) -> Chord {
        let degree = degrees[((slot % degrees.count) + degrees.count) % degrees.count]
        return Chord(root: keyRoot + Self.degreeOffsets[degree], quality: Self.degreeQualities[degree])
    }

    var chords: [Chord] { (0..<Self.slotCount).map { chord(at: $0) } }

    /// "I V vi IV"
    var romanNumerals: String { degrees.map { Self.degreeNames[$0] }.joined(separator: " ") }

    struct Preset: Identifiable, Hashable {
        let name: String
        let degrees: [Int]
        var id: String { name }
    }

    static let presets: [Preset] = [
        Preset(name: "Pop  I V vi IV", degrees: [0, 4, 5, 3]),
        Preset(name: "Sensitive  vi IV I V", degrees: [5, 3, 0, 4]),
        Preset(name: "50s  I vi IV V", degrees: [0, 5, 3, 4]),
        Preset(name: "Jazzy  ii V I I", degrees: [1, 4, 0, 0]),
    ]
}
