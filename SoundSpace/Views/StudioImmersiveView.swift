import RealityKit
import SwiftUI

/// The studio: instruments placed around you in your own room.
struct StudioImmersiveView: View {
    @Environment(StudioModel.self) private var studio

    var body: some View {
        RealityView { content in
            for instrument in Instrument.all {
                let root = InstrumentFactory.make(instrument)
                content.add(root)
                studio.register(root: root, for: instrument)
            }
            studio.applyEnabledFlags()
        } update: { _ in
            // Re-runs when the toggles in the control panel change.
            studio.applyEnabledFlags()
        }
        // Look at an instrument and pinch to play it.
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in studio.handleTap(on: value.entity) }
        )
        // In Arrange mode, pinch and hold, then move your hand to reposition the instrument.
        .gesture(
            DragGesture()
                .targetedToAnyEntity()
                .onChanged { value in
                    guard let root = studio.rootEntity(of: value.entity), let parent = root.parent else { return }
                    let location = value.convert(value.location3D, from: .local, to: parent)
                    studio.handleDragChanged(entity: value.entity, location: location)
                }
                .onEnded { _ in studio.handleDragEnded() }
        )
        .onDisappear {
            studio.isImmersiveOpen = false
            studio.stopLoop()
            studio.stopLesson()
        }
    }
}
