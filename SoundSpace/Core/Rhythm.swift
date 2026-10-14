import Foundation

/// Converts between beats and seconds at a tempo.
struct BeatClock: Equatable {
    var bpm: Double
    var secondsPerBeat: Double { 60 / bpm }
    func seconds(forBeat beat: Double) -> Double { beat * secondsPerBeat }
    func beat(forSeconds seconds: Double) -> Double { seconds / secondsPerBeat }
}

struct LoopHit: Hashable {
    var key: String      // instrument zone key, e.g. "getabera#0"
    var step: Int        // position on the 16th-note grid
}

/// Records hits into a fixed-length loop (default: 8 beats) on a 16th-note grid.
struct LoopRecorder {
    let beats: Int
    let subdivisions: Int            // steps per beat (4 = 16th notes)
    private(set) var hits: [LoopHit] = []

    init(beats: Int = 8, subdivisions: Int = 4) {
        self.beats = beats
        self.subdivisions = subdivisions
    }

    var stepCount: Int { beats * subdivisions }
    var isEmpty: Bool { hits.isEmpty }

    /// Snaps a time position (in beats from the loop start) to the nearest step, wrapping at the end of the loop.
    /// Example: a hit at beat 2.97 snaps to step 12 (beat 3.0); a hit at beat 7.9 wraps round to step 0.
    func quantize(beat: Double) -> Int {
        let raw = Int((beat * Double(subdivisions)).rounded())
        return ((raw % stepCount) + stepCount) % stepCount
    }

    mutating func record(key: String, atBeat beat: Double) {
        let hit = LoopHit(key: key, step: quantize(beat: beat))
        if !hits.contains(hit) { hits.append(hit) }      // the same zone on the same step is only stored once
    }

    mutating func clear() { hits.removeAll() }

    func hits(atStep step: Int) -> [LoopHit] { hits.filter { $0.step == step } }
}

// MARK: - Rhythm lesson

/// One note the learner should play. `beat` is measured from the end of the count-in.
struct PatternHit: Hashable {
    var key: String
    var beat: Double
}

struct RhythmPattern {
    let id: String
    let title: String
    let summary: String
    let bpm: Double
    let beats: Int
    let hits: [PatternHit]

    /// The instruments a learner needs for this pattern (used to switch them on before the lesson starts).
    var instrumentIDs: Set<String> {
        Set(hits.map { String($0.key.split(separator: "#").first ?? "") })
    }

    /// A simple 8-beat pattern for the demo. It is written for teaching the interaction and is not a transcription
    /// of a traditional Kandyan rhythm.
    static let firstGroove = RhythmPattern(
        id: "first-groove", title: "First groove",
        summary: "Follow the glowing drum. Hit it when it pulses.",
        bpm: 80, beats: 8,
        hits: [
            PatternHit(key: "getabera#0", beat: 0),
            PatternHit(key: "thammattama#0", beat: 1),
            PatternHit(key: "getabera#0", beat: 2),
            PatternHit(key: "thammattama#1", beat: 3),
            PatternHit(key: "getabera#0", beat: 4),
            PatternHit(key: "thammattama#0", beat: 5),
            PatternHit(key: "rabana#0", beat: 6),
            PatternHit(key: "rabana#0", beat: 7),
        ])
}

extension RhythmPattern {
    /// Two bars of a basic rock beat on the drum kit: kick on 1 and 3, snare on 2 and 4, hi-hat on the off-beats.
    static let rockBeat: RhythmPattern = {
        var hits: [PatternHit] = []
        for beat in 0..<8 {
            hits.append(PatternHit(key: beat % 2 == 0 ? "drumkit#0" : "drumkit#1", beat: Double(beat)))   // kick / snare
            hits.append(PatternHit(key: "drumkit#2", beat: Double(beat) + 0.5))                            // hi-hat
        }
        return RhythmPattern(id: "rock-beat", title: "Rock beat",
                             summary: "Kick on 1 and 3, snare on 2 and 4, hi-hat in between. Follow the glowing drum.",
                             bpm: 80, beats: 8, hits: hits.sorted { $0.beat < $1.beat })
    }()

    static let all: [RhythmPattern] = [rockBeat, firstGroove]
}

struct ExpectedHit: Equatable {
    var key: String
    var time: Double     // seconds from lesson start
}

struct PlayedHit: Equatable {
    var key: String
    var time: Double
}

struct LessonResult: Equatable {
    var matched: Int
    var total: Int
    var extraHits: Int
    var averageOffsetMs: Double      // average |timing error| of matched hits
    var accuracyPercent: Int { total == 0 ? 0 : Int((Double(matched) / Double(total) * 100).rounded()) }
}

enum LessonScorer {
    /// Matches each expected hit with the closest unused played hit on the same instrument zone within `window` seconds.
    static func score(expected: [ExpectedHit], played: [PlayedHit], window: Double = 0.25) -> LessonResult {
        var used = Set<Int>()
        var matched = 0
        var offsets: [Double] = []
        for hit in expected {
            var bestIndex: Int?
            var bestDistance = Double.infinity
            for (index, play) in played.enumerated() where !used.contains(index) && play.key == hit.key {
                let distance = abs(play.time - hit.time)
                if distance <= window && distance < bestDistance { bestIndex = index; bestDistance = distance }
            }
            if let bestIndex {
                used.insert(bestIndex)
                matched += 1
                offsets.append(bestDistance)
            }
        }
        let average = offsets.isEmpty ? 0 : offsets.reduce(0, +) / Double(offsets.count) * 1000
        return LessonResult(matched: matched, total: expected.count, extraHits: played.count - used.count, averageOffsetMs: average)
    }
}
