import SwiftUI

@main
struct SoundSpaceApp: App {
    @State private var studio = StudioModel()

    init() {
        InstrumentComponent.registerComponent()
    }

    var body: some Scene {
        // 1. Control panel: a normal window with glass material.
        WindowGroup {
            ControlPanelView()
                .environment(studio)
        }
        .defaultSize(width: 560, height: 820)

        // 2. The studio: an immersive space (mixed), so instruments appear in your own room.
        ImmersiveSpace(id: "studio") {
            StudioImmersiveView()
                .environment(studio)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
