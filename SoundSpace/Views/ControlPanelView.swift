import SwiftUI

/// The window you see first: pick instruments, enter the studio, record loops and try the lesson.
struct ControlPanelView: View {
    @Environment(StudioModel.self) private var studio
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    instrumentSection
                    chordSection
                    studioSection
                    loopSection
                    lessonSection
                }
                .padding(28)
            }
            .navigationTitle("SoundSpace")
        }
        .ornament(attachmentAnchor: .scene(.bottom)) { TransportBar().environment(studio) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Play a drum kit and a chord synth all around you").font(.title3).foregroundStyle(.secondary)
        }
    }

    // MARK: Instruments

    private var instrumentSection: some View {
        @Bindable var studio = studio
        return VStack(alignment: .leading, spacing: 12) {
            Text("Instruments").font(.headline)
            Picker("Instrument set", selection: Binding(get: { studio.kit }, set: { studio.selectKit($0) })) {
                ForEach(StudioModel.Kit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("kitPicker")
            ForEach(studio.kit.instruments) { instrument in
                Toggle(isOn: Binding(get: { studio.enabled[instrument.id] ?? true },
                                     set: { studio.enabled[instrument.id] = $0 })) {
                    VStack(alignment: .leading) {
                        Text(instrument.name).font(.title3.bold())
                        Text(instrument.subtitle).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("toggle-\(instrument.id)")
            }
        }
    }

    // MARK: Chords

    private var chordSection: some View {
        @Bindable var studio = studio
        return VStack(alignment: .leading, spacing: 12) {
            Text("Chord progression").font(.headline)
            HStack {
                Picker("Key", selection: Binding(get: { studio.progression.keyRoot }, set: { studio.setKey($0) })) {
                    ForEach(0..<12, id: \.self) { Text("\(Chord.noteNames[$0]) major").tag($0) }
                }
                .pickerStyle(.menu)
                Menu("Presets", systemImage: "music.note.list") {
                    ForEach(ChordProgression.presets) { preset in
                        Button(preset.name) { studio.applyPreset(preset) }
                    }
                }
            }
            HStack(spacing: 8) {
                ForEach(0..<ChordProgression.slotCount, id: \.self) { slot in
                    Menu {
                        ForEach(0..<ChordProgression.degreeNames.count, id: \.self) { degree in
                            let option = ChordProgression(keyRoot: studio.progression.keyRoot, degrees: [degree]).chord(at: 0)
                            Button("\(option.name)  (\(ChordProgression.degreeNames[degree]))") { studio.setDegree(degree, slot: slot) }
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Text("Bar \(slot + 1)").font(.caption).foregroundStyle(.secondary)
                            Text(studio.progression.chord(at: slot).name).font(.title2.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(studio.currentChordSlot == slot ? Color.accentColor.opacity(0.4) : Color.secondary.opacity(0.15),
                                    in: RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityIdentifier("chordSlot-\(slot)")
                }
            }
            Toggle("Synth plays the chords while looping", isOn: $studio.chordsBacking)
            Text("Tap a bar to change its chord. In the studio, pinch the pads to play chords yourself.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    // MARK: Studio

    private var studioSection: some View {
        @Bindable var studio = studio
        return VStack(alignment: .leading, spacing: 12) {
            Text("Studio").font(.headline)
            Button {
                Task {
                    if studio.isImmersiveOpen {
                        await dismissImmersiveSpace()
                    } else {
                        if case .opened = await openImmersiveSpace(id: "studio") { studio.isImmersiveOpen = true }
                    }
                }
            } label: {
                Label(studio.isImmersiveOpen ? "Leave studio" : "Enter studio",
                      systemImage: studio.isImmersiveOpen ? "xmark.circle" : "cube.transparent")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("enterStudio")

            Picker("Mode", selection: $studio.mode) {
                ForEach(StudioModel.Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Text(studio.mode == .play ? "Look at a drum and pinch to play it."
                                      : "Pinch and hold an instrument, then move your hand to reposition it.")
                .font(.subheadline).foregroundStyle(.secondary)

            Button("Reset positions", systemImage: "arrow.uturn.backward") { studio.resetPositions() }
        }
    }

    // MARK: Loop

    private var loopSection: some View {
        @Bindable var studio = studio
        return VStack(alignment: .leading, spacing: 12) {
            Text("Loop recorder · 4 bars").font(.headline)
            Text("The chords play by themselves. Press Record and play the drums on top.").font(.subheadline).foregroundStyle(.secondary)
            Stepper("Tempo \(Int(studio.bpm)) bpm", value: $studio.bpm, in: 60...140, step: 4)
                .disabled(studio.loopState != .idle)
            StepIndicator(currentStep: studio.currentStep, stepCount: studio.recorder.stepCount,
                          active: studio.loopState != .idle, hits: Set(studio.recorder.hits.map(\.step)))
            HStack {
                Button(studio.loopState == .recording ? "Recording…" : "Record", systemImage: "record.circle") { studio.startRecording() }
                    .disabled(!studio.isImmersiveOpen || studio.loopState == .recording)
                Button("Play", systemImage: "play.fill") { studio.startPlayback() }
                    .disabled(studio.recorder.isEmpty || studio.loopState != .idle)
                Button("Stop", systemImage: "stop.fill") { studio.stopLoop() }
                    .disabled(studio.loopState == .idle)
                Button("Clear", systemImage: "trash") { studio.clearLoop() }
                    .disabled(studio.recorder.isEmpty)
            }
            if !studio.isImmersiveOpen {
                Text("Enter the studio to record a loop.").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Lesson

    private var lessonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rhythm lesson").font(.headline)
            Picker("Pattern", selection: Binding(get: { studio.lessonPattern.id },
                                                  set: { id in if let pattern = RhythmPattern.all.first(where: { $0.id == id }) { studio.selectLessonPattern(pattern) } })) {
                ForEach(RhythmPattern.all, id: \.id) { Text($0.title).tag($0.id) }
            }
            .pickerStyle(.segmented)
            Text(studio.lessonPattern.title).font(.title3.bold())
            Text(studio.lessonPattern.summary).foregroundStyle(.secondary)
            switch studio.lessonState {
            case .idle:
                EmptyView()
            case .countIn:
                Label("Get ready…", systemImage: "metronome").font(.title3)
            case .running:
                Label("Next: \(studio.nextCue ?? "…")", systemImage: "hand.tap").font(.title3.bold())
            case .finished(let result):
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(result.accuracyPercent)% — \(result.matched) of \(result.total) hits").font(.title3.bold())
                    Text("Average timing error \(Int(result.averageOffsetMs)) ms · \(result.extraHits) extra hits")
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Button(studio.lessonState == .idle ? "Start lesson" : "Restart lesson", systemImage: "graduationcap") { studio.startLesson() }
                    .disabled(!studio.isImmersiveOpen)
                    .accessibilityIdentifier("startLesson")
                if studio.lessonState != .idle {
                    Button("Stop", systemImage: "xmark") { studio.stopLesson() }
                }
            }
        }
    }
}

/// One block per 16th-note step (four per beat); lights up as the loop plays.
struct StepIndicator: View {
    let currentStep: Int
    let stepCount: Int
    let active: Bool
    let hits: Set<Int>

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<stepCount, id: \.self) { step in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color(for: step))
                    .frame(height: step % 4 == 0 ? 26 : 18)
            }
        }
        .frame(height: 28)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loop position, step \(currentStep + 1) of \(stepCount)")
    }

    private func color(for step: Int) -> Color {
        if active && step == currentStep { return .white }
        return hits.contains(step) ? .orange : .secondary.opacity(0.3)
    }
}

/// Ornament under the window with the main loop controls, always within reach.
struct TransportBar: View {
    @Environment(StudioModel.self) private var studio

    var body: some View {
        HStack(spacing: 16) {
            Button(studio.loopState == .recording ? "Recording" : "Record", systemImage: "record.circle") { studio.startRecording() }
                .disabled(!studio.isImmersiveOpen || studio.loopState == .recording)
            Button("Play", systemImage: "play.fill") { studio.startPlayback() }
                .disabled(studio.recorder.isEmpty || studio.loopState != .idle)
            Button("Stop", systemImage: "stop.fill") { studio.stopLoop() }
                .disabled(studio.loopState == .idle)
        }
        .labelStyle(.iconOnly)
        .padding()
        .glassBackgroundEffect()
    }
}
