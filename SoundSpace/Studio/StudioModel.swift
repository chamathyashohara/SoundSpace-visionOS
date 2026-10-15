import Observation
import RealityKit
import SwiftUI

/// Everything that changes while you play: which mode you are in, the loop recorder and the rhythm lesson.
@MainActor
@Observable
final class StudioModel {
    enum Mode: String, CaseIterable { case play = "Play", arrange = "Arrange" }
    enum LoopState: Equatable { case idle, recording, playing }
    enum LessonState: Equatable { case idle, countIn, running, finished(LessonResult) }

    /// The loop is always 4 bars of 4 beats, one bar per chord of the progression.
    static let loopBeats = 16

    // Control panel state
    var enabled: [String: Bool] = Dictionary(uniqueKeysWithValues: Instrument.all.map { ($0.id, true) })
    var mode: Mode = .play
    var isImmersiveOpen = false
    var bpm: Double = 96

    // Chords
    private(set) var progression = ChordProgression()
    var chordsBacking = true               // the synth plays the progression by itself while looping
    private(set) var currentChordSlot: Int?

    // Loop recorder
    private(set) var loopState: LoopState = .idle
    private(set) var currentStep = 0
    private(set) var recorder = LoopRecorder(beats: StudioModel.loopBeats)

    // Lesson
    private(set) var lessonState: LessonState = .idle
    private(set) var lessonPattern = RhythmPattern.rockBeat
    private(set) var nextCue: String?

    @ObservationIgnored private let sounds = SoundBank()
    @ObservationIgnored private var zoneEntities: [String: Entity] = [:]
    @ObservationIgnored private var chordLabels: [Int: Entity] = [:]
    @ObservationIgnored private var rootEntities: [String: Entity] = [:]
    @ObservationIgnored private var loopTask: Task<Void, Never>?
    @ObservationIgnored private var lessonTask: Task<Void, Never>?
    @ObservationIgnored private var loopStart = Date()
    @ObservationIgnored private var lessonStart = Date()
    @ObservationIgnored private var playedInLesson: [PlayedHit] = []
    @ObservationIgnored private var dragOffset: SIMD3<Float>?

    init() { sounds.preload() }

    var clock: BeatClock { BeatClock(bpm: bpm) }

    // MARK: Entity registry (filled by the immersive view)

    func register(root: Entity, for instrument: Instrument) {
        rootEntities[instrument.id] = root
        for child in root.children where child.components[InstrumentComponent.self] != nil {
            if let component = child.components[InstrumentComponent.self] { zoneEntities[component.key] = child }
        }
        for child in root.children where child.name.hasPrefix(InstrumentFactory.chordLabelPrefix) {
            if let slot = Int(child.name.dropFirst(InstrumentFactory.chordLabelPrefix.count)) { chordLabels[slot] = child }
        }
        if instrument.chordPads { refreshChordLabels() }
    }

    // MARK: Chords

    func setKey(_ pitchClass: Int) {
        progression.keyRoot = ((pitchClass % 12) + 12) % 12
        refreshChordLabels()
    }

    func setDegree(_ degree: Int, slot: Int) {
        guard progression.degrees.indices.contains(slot) else { return }
        progression.degrees[slot] = min(max(degree, 0), 5)
        refreshChordLabels()
    }

    func applyPreset(_ preset: ChordProgression.Preset) {
        progression = ChordProgression(keyRoot: progression.keyRoot, degrees: preset.degrees)
        refreshChordLabels()
    }

    private func refreshChordLabels() {
        for (slot, label) in chordLabels {
            InstrumentFactory.updateChordLabel(label, slot: slot, text: progression.chord(at: slot).name)
        }
    }

    private func chordSlot(in key: String) -> Int? {
        let prefix = Instrument.chordSynth.id + "#"
        guard key.hasPrefix(prefix) else { return nil }
        return Int(key.dropFirst(prefix.count))
    }

    private func audio(forKey key: String) -> AudioFileResource? {
        if let slot = chordSlot(in: key) { return sounds.resource(for: progression.chord(at: slot)) }
        return sounds.resource(forKey: key)
    }

    func applyEnabledFlags() {
        for (id, root) in rootEntities { root.isEnabled = enabled[id] ?? true }
    }

    func resetPositions() {
        for instrument in Instrument.all { rootEntities[instrument.id]?.position = instrument.home }
    }

    // MARK: Striking

    /// Called when the user pinches an instrument (look + pinch).
    func handleTap(on entity: Entity) {
        guard mode == .play, let component = entity.components[InstrumentComponent.self], !component.isRoot else { return }
        strike(key: component.key, record: true)
    }

    /// Plays one zone. `record` is false when the loop itself is replaying the hit.
    func strike(key: String, record: Bool) {
        guard let entity = zoneEntities[key] else { return }
        if let resource = audio(forKey: key) { entity.playAudio(resource) }
        bounce(entity)
        guard record else { return }
        if loopState == .recording {
            let beat = clock.beat(forSeconds: Date().timeIntervalSince(loopStart))
            recorder.record(key: key, atBeat: beat)
        }
        if lessonState == .countIn || lessonState == .running {
            playedInLesson.append(PlayedHit(key: key, time: Date().timeIntervalSince(lessonStart)))
        }
    }

    /// A short squash and release so the hit feels physical. Scale is the only thing changed; position stays put.
    private func bounce(_ entity: Entity) {
        var down = entity.transform
        down.scale = [1.06, 0.9, 1.06]
        entity.move(to: down, relativeTo: entity.parent, duration: 0.05)
        Task { [weak entity] in
            try? await Task.sleep(for: .milliseconds(60))
            guard let entity else { return }
            var up = entity.transform
            up.scale = [1, 1, 1]
            entity.move(to: up, relativeTo: entity.parent, duration: 0.12)
        }
    }

    /// Bigger, slower pulse used as the "hit this next" cue in lessons.
    private func pulse(_ entity: Entity) {
        var big = entity.transform
        big.scale = [1.25, 1.25, 1.25]
        entity.move(to: big, relativeTo: entity.parent, duration: 0.2)
        Task { [weak entity] in
            try? await Task.sleep(for: .milliseconds(260))
            guard let entity else { return }
            var normal = entity.transform
            normal.scale = [1, 1, 1]
            entity.move(to: normal, relativeTo: entity.parent, duration: 0.2)
        }
    }

    // MARK: Moving instruments

    func handleDragChanged(entity: Entity, location: SIMD3<Float>) {
        guard mode == .arrange, let root = rootEntity(of: entity) else { return }
        if dragOffset == nil { dragOffset = root.position - location }
        root.position = StudioBounds.clamp(location + (dragOffset ?? .zero))
    }

    func handleDragEnded() { dragOffset = nil }

    func rootEntity(of entity: Entity) -> Entity? {
        var current: Entity? = entity
        while let node = current {
            if let component = node.components[InstrumentComponent.self], component.isRoot { return node }
            current = node.parent
        }
        return nil
    }

    // MARK: Loop recorder

    /// Records 4 bars (16 beats), then plays the loop back repeatedly. While it runs, the synth plays one chord per bar
    /// (if `chordsBacking` is on), so you can play the drum kit in time with the progression.
    func startRecording() {
        stopLoop()
        recorder = LoopRecorder(beats: Self.loopBeats)
        loopState = .recording
        loopStart = Date()
        runLoop(recordingSteps: recorder.stepCount)
    }

    func startPlayback() {
        guard !recorder.isEmpty else { return }
        stopLoop()
        loopState = .playing
        runLoop(recordingSteps: 0)
    }

    /// One task drives everything on a 16th-note grid. Deadlines are absolute (origin + n steps), so the loop does not drift.
    private func runLoop(recordingSteps: Int) {
        let stepSeconds = clock.secondsPerBeat / 4
        let stepsPerBar = 16
        let origin = ContinuousClock.now
        loopTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                guard let self else { return }
                if self.loopState == .recording && tick >= recordingSteps { self.loopState = .playing }   // recording done: hear it back
                let step = tick % self.recorder.stepCount
                self.currentStep = step
                if step % stepsPerBar == 0 {
                    let slot = (step / stepsPerBar) % ChordProgression.slotCount
                    self.currentChordSlot = slot
                    if self.chordsBacking { self.strike(key: Instrument.key(Instrument.chordSynth.id, zone: slot), record: false) }
                }
                if self.loopState == .playing {
                    for hit in self.recorder.hits(atStep: step) { self.strike(key: hit.key, record: false) }
                }
                tick += 1
                try? await Task.sleep(until: origin + .seconds(stepSeconds * Double(tick)), clock: .continuous)
            }
        }
    }

    func stopLoop() {
        loopTask?.cancel()
        loopTask = nil
        loopState = .idle
        currentStep = 0
        currentChordSlot = nil
    }

    func clearLoop() {
        stopLoop()
        recorder.clear()
    }

    // MARK: Rhythm lesson

    func selectLessonPattern(_ pattern: RhythmPattern) {
        guard lessonState != .countIn, lessonState != .running else { return }
        lessonPattern = pattern
        lessonState = .idle
    }

    func startLesson() {
        stopLesson()
        stopLoop()
        mode = .play
        let pattern = lessonPattern
        // Make sure the instruments this pattern needs are in the room.
        for id in pattern.instrumentIDs { enabled[id] = true }
        applyEnabledFlags()
        let clock = BeatClock(bpm: pattern.bpm)
        let countIn = 4.0
        let expected = pattern.hits.map { ExpectedHit(key: $0.key, time: clock.seconds(forBeat: countIn + $0.beat)) }
        playedInLesson = []
        lessonState = .countIn
        lessonStart = Date()
        lessonTask = Task { [weak self] in
            // Cue each hit one beat early by pulsing the instrument that is coming up.
            for hit in expected {
                let cueTime = hit.time - clock.secondsPerBeat
                while !Task.isCancelled, let self, Date().timeIntervalSince(self.lessonStart) < cueTime {
                    if self.lessonState == .countIn, Date().timeIntervalSince(self.lessonStart) >= clock.seconds(forBeat: countIn) {
                        self.lessonState = .running
                    }
                    try? await Task.sleep(for: .milliseconds(10))
                }
                guard !Task.isCancelled, let self else { return }
                if self.lessonState == .countIn, Date().timeIntervalSince(self.lessonStart) >= clock.seconds(forBeat: countIn) {
                    self.lessonState = .running
                }
                self.nextCue = Instrument.displayName(forKey: hit.key)
                if let entity = self.zoneEntities[hit.key] { self.pulse(entity) }
            }
            // Wait for the last hit plus the timing window, then score.
            let end = (expected.last?.time ?? 0) + 0.6
            while !Task.isCancelled, let self, Date().timeIntervalSince(self.lessonStart) < end {
                try? await Task.sleep(for: .milliseconds(20))
            }
            guard !Task.isCancelled, let self else { return }
            self.lessonState = .finished(LessonScorer.score(expected: expected, played: self.playedInLesson))
            self.nextCue = nil
        }
    }

    func stopLesson() {
        lessonTask?.cancel()
        lessonTask = nil
        lessonState = .idle
        nextCue = nil
    }
}
