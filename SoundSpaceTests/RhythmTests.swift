import XCTest
@testable import SoundSpace

final class LoopRecorderTests: XCTestCase {
    func testQuantizeSnapsToNearestSixteenth() {
        let recorder = LoopRecorder(beats: 8)
        XCTAssertEqual(recorder.stepCount, 32)
        XCTAssertEqual(recorder.quantize(beat: 2.97), 12)     // beat 3.0
        XCTAssertEqual(recorder.quantize(beat: 0.10), 0)
        XCTAssertEqual(recorder.quantize(beat: 0.14), 1)      // 0.14 * 4 = 0.56 -> 1
        XCTAssertEqual(recorder.quantize(beat: 7.9), 0)       // 31.6 -> 32 -> wraps to the start
    }

    func testNegativeBeatsWrap() {
        XCTAssertEqual(LoopRecorder(beats: 8).quantize(beat: -0.25), 31)
    }

    func testDuplicateHitsAreStoredOnce() {
        var recorder = LoopRecorder(beats: 8)
        recorder.record(key: "drumkit#0", atBeat: 1.0)
        recorder.record(key: "drumkit#0", atBeat: 1.02)
        recorder.record(key: "drumkit#1", atBeat: 1.0)
        XCTAssertEqual(recorder.hits.count, 2)
        XCTAssertEqual(recorder.hits(atStep: 4).count, 2)
    }

    func testClear() {
        var recorder = LoopRecorder(beats: 8)
        recorder.record(key: "a#0", atBeat: 3)
        recorder.clear()
        XCTAssertTrue(recorder.isEmpty)
    }

    func testBeatClock() {
        let clock = BeatClock(bpm: 120)
        XCTAssertEqual(clock.secondsPerBeat, 0.5, accuracy: 1e-9)
        XCTAssertEqual(clock.seconds(forBeat: 8), 4, accuracy: 1e-9)
        XCTAssertEqual(clock.beat(forSeconds: 1.25), 2.5, accuracy: 1e-9)
    }
}

final class LessonScorerTests: XCTestCase {
    private let expected = [ExpectedHit(key: "a#0", time: 1.0), ExpectedHit(key: "b#0", time: 2.0), ExpectedHit(key: "a#0", time: 3.0)]

    func testPerfectPlay() {
        let played = expected.map { PlayedHit(key: $0.key, time: $0.time) }
        let result = LessonScorer.score(expected: expected, played: played)
        XCTAssertEqual(result.matched, 3)
        XCTAssertEqual(result.accuracyPercent, 100)
        XCTAssertEqual(result.averageOffsetMs, 0, accuracy: 0.001)
        XCTAssertEqual(result.extraHits, 0)
    }

    func testTimingWindow() {
        let played = [PlayedHit(key: "a#0", time: 1.2), PlayedHit(key: "b#0", time: 2.4), PlayedHit(key: "a#0", time: 3.0)]
        let result = LessonScorer.score(expected: expected, played: played, window: 0.25)
        XCTAssertEqual(result.matched, 2)             // 2.4 is 0.4 s late: outside the window
        XCTAssertEqual(result.extraHits, 1)
        XCTAssertEqual(result.averageOffsetMs, 100, accuracy: 0.001)   // (0.2 + 0.0) / 2
    }

    func testWrongInstrumentDoesNotMatch() {
        let result = LessonScorer.score(expected: expected, played: [PlayedHit(key: "c#0", time: 1.0)])
        XCTAssertEqual(result.matched, 0)
        XCTAssertEqual(result.extraHits, 1)
    }

    func testOnePlayedHitCannotMatchTwoExpectedHits() {
        let result = LessonScorer.score(expected: [ExpectedHit(key: "a#0", time: 1.0), ExpectedHit(key: "a#0", time: 1.1)],
                                        played: [PlayedHit(key: "a#0", time: 1.05)])
        XCTAssertEqual(result.matched, 1)
    }

    func testEmptyLesson() {
        XCTAssertEqual(LessonScorer.score(expected: [], played: []).accuracyPercent, 0)
    }
}

final class InstrumentTests: XCTestCase {
    func testDefaultLayoutDoesNotOverlap() {
        XCTAssertTrue(StudioLayout.isSpacedOut(Instrument.all))
    }

    func testInstrumentIDsAreUnique() {
        XCTAssertEqual(Set(Instrument.all.map(\.id)).count, Instrument.all.count, "ids must be unique")
    }

    func testDrumKitAndSynthZones() {
        XCTAssertEqual(Instrument.drumKit.zoneCount, 7)
        XCTAssertEqual(Instrument.drumKitZoneNames.count, Instrument.drumKit.zoneCount)
        XCTAssertEqual(Instrument.chordSynth.zoneCount, ChordProgression.slotCount)
        XCTAssertTrue(Instrument.chordSynth.chordPads)
        XCTAssertEqual(Instrument.displayName(forKey: "drumkit#1"), "Snare")
        XCTAssertEqual(Instrument.displayName(forKey: "drumkit#5"), "Floor tom")
        XCTAssertEqual(Instrument.displayName(forKey: "drumkit#6"), "Ride")
        XCTAssertEqual(Instrument.displayName(forKey: "chordpads#2"), "Chord Synth")
    }

    func testInstrumentsWithinArmsReach() {
        for instrument in Instrument.all {
            XCTAssertLessThan(StudioLayout.distanceFromUser(instrument.home), 1.8, instrument.name)
        }
    }

    func testBoundsClamp() {
        let clamped = StudioBounds.clamp([5, -3, 2])
        XCTAssertEqual(clamped.x, 1.2, accuracy: 1e-6)
        XCTAssertEqual(clamped.y, 0.5, accuracy: 1e-6)
        XCTAssertEqual(clamped.z, -0.35, accuracy: 1e-6)
    }

    func testKeysAndZones() {
        XCTAssertEqual(Instrument.key("drumkit", zone: 1), "drumkit#1")
        XCTAssertEqual(Instrument.displayName(forKey: "drumkit#0"), "Kick")
    }
}

final class RockBeatTests: XCTestCase {
    func testRockBeatIsValid() {
        let pattern = RhythmPattern.rockBeat
        XCTAssertEqual(pattern.hits.count, 16)          // 8 kick/snare hits + 8 hi-hat hits
        XCTAssertTrue(pattern.hits.allSatisfy { $0.beat >= 0 && $0.beat < Double(pattern.beats) })
        XCTAssertEqual(pattern.instrumentIDs, [Instrument.drumKit.id])
        XCTAssertEqual(pattern.hits.map(\.beat), pattern.hits.map(\.beat).sorted())
    }

    func testKickOnOneAndThreeSnareOnTwoAndFour() {
        let hits = RhythmPattern.rockBeat.hits
        XCTAssertTrue(hits.contains(PatternHit(key: "drumkit#0", beat: 0)))
        XCTAssertTrue(hits.contains(PatternHit(key: "drumkit#1", beat: 1)))
        XCTAssertTrue(hits.contains(PatternHit(key: "drumkit#0", beat: 2)))
        XCTAssertTrue(hits.contains(PatternHit(key: "drumkit#1", beat: 3)))
    }

    func testEveryPatternUsesKnownZones() {
        for pattern in RhythmPattern.all {
            for hit in pattern.hits {
                let parts = hit.key.split(separator: "#")
                let instrument = Instrument.named(String(parts[0]))
                XCTAssertNotNil(instrument, hit.key)
                XCTAssertLessThan(Int(parts[1]) ?? 99, instrument?.zoneCount ?? 0, hit.key)
            }
        }
    }
}
