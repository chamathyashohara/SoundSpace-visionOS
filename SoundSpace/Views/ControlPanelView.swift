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
            Text("Play Sri Lankan rhythms all around you").font(.title3).foregroundStyle(.secondary)
        }
    }

    // MARK: Instruments

    private var instrumentSection: some View {
        @Bindable var studio = studio
        return VStack(alignment: .leading, spacing: 12) {
            Text("Instruments").font(.headline)
            ForEach(Instrument.all) { instrument in
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
            Text("Loop recorder · 8 beats").font(.headline)
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

/// Eight beats of four steps each; lights up as the loop plays.
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
