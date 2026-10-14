import XCTest
@testable import SoundSpace

final class ChordTests: XCTestCase {
    func testNamesAndNotes() {
        XCTAssertEqual(Chord(root: 0, quality: .major).name, "C")
        XCTAssertEqual(Chord(root: 9, quality: .minor).name, "Am")
        XCTAssertEqual(Chord(root: 10, quality: .major).name, "B♭")
        XCTAssertEqual(Chord(root: 0, quality: .major).pitchClasses, [0, 4, 7])
        XCTAssertEqual(Chord(root: 9, quality: .minor).pitchClasses, [9, 0, 4])       // A C E
        XCTAssertEqual(Chord(root: 11, quality: .major).pitchClasses, [11, 3, 6])     // B D# F# wraps past 12
    }

    func testRootWrapsAround() {
        XCTAssertEqual(Chord(root: 12, quality: .major).root, 0)
        XCTAssertEqual(Chord(root: -1, quality: .minor).root, 11)
    }

    func testSoundFileNamesMatchTheGeneratedFiles() {
        XCTAssertEqual(Chord(root: 0, quality: .major).soundFile, "chord_0_maj")
        XCTAssertEqual(Chord(root: 9, quality: .minor).soundFile, "chord_9_min")
    }

    func testPopProgressionInC() {
        let progression = ChordProgression(keyRoot: 0, degrees: [0, 4, 5, 3])
        XCTAssertEqual(progression.chords.map(\.name), ["C", "G", "Am", "F"])
        XCTAssertEqual(progression.romanNumerals, "I V vi IV")
    }

    func testChangingKeyTransposesEverything() {
        let progression = ChordProgression(keyRoot: 7, degrees: [0, 4, 5, 3])       // key of G
        XCTAssertEqual(progression.chords.map(\.name), ["G", "D", "Em", "C"])
    }

    func testAllSixDegreesInCMajor() {
        let names = (0..<6).map { ChordProgression(keyRoot: 0, degrees: [$0]).chord(at: 0).name }
        XCTAssertEqual(names, ["C", "Dm", "Em", "F", "G", "Am"])
    }

    func testDegreesAreClampedAndPadded() {
        let progression = ChordProgression(keyRoot: 0, degrees: [9, -3])
        XCTAssertEqual(progression.degrees, [5, 0, 0, 0])
    }

    func testSlotsWrapAround() {
        let progression = ChordProgression()
        XCTAssertEqual(progression.chord(at: 4), progression.chord(at: 0))
        XCTAssertEqual(progression.chord(at: -1), progression.chord(at: 3))
    }

    func testPresetsHaveFourValidChords() {
        for preset in ChordProgression.presets {
            XCTAssertEqual(preset.degrees.count, ChordProgression.slotCount, preset.name)
            XCTAssertTrue(preset.degrees.allSatisfy { (0...5).contains($0) }, preset.name)
        }
    }

    func testLoopRecorderHoldsFourBars() {
        let recorder = LoopRecorder(beats: 16)
        XCTAssertEqual(recorder.stepCount, 64)
        XCTAssertEqual(recorder.quantize(beat: 4.0), 16)       // start of bar 2
        XCTAssertEqual(recorder.quantize(beat: 15.9), 0)       // wraps to the start of the loop
    }
}
