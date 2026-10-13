import RealityKit
import SwiftUI
import UIKit

/// Builds the 3D instruments from RealityKit primitives (cylinders and spheres), so no 3D models are needed.
enum InstrumentFactory {
    private static func material(_ color: UIColor, metallic: Bool = false) -> SimpleMaterial {
        SimpleMaterial(color: color, roughness: metallic ? 0.25 : 0.6, isMetallic: metallic)
    }

    /// Makes one playable part: it can be looked at (hover glow), pinched (input target) and it plays sound from its own position.
    private static func zone(_ instrument: Instrument, index: Int, mesh: MeshResource, color: UIColor,
                             metallic: Bool = false, position: SIMD3<Float>, orientation: simd_quatf = .init(angle: 0, axis: [0, 1, 0])) -> ModelEntity {
        let entity = ModelEntity(mesh: mesh, materials: [material(color, metallic: metallic)])
        entity.name = Instrument.key(instrument.id, zone: index)
        entity.position = position
        entity.orientation = orientation
        entity.components.set(InstrumentComponent(instrumentID: instrument.id, zone: index))
        entity.components.set(InputTargetComponent())
        entity.components.set(HoverEffectComponent())
        entity.generateCollisionShapes(recursive: false)
        var audio = SpatialAudioComponent()
        audio.gain = -3
        entity.components.set(audio)
        return entity
    }

    /// Floating name label above the instrument.
    private static func label(_ text: String, height: Float) -> ModelEntity {
        let mesh = MeshResource.generateText(text, extrusionDepth: 0.004, font: .systemFont(ofSize: 0.06, weight: .semibold))
        let entity = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: .white)])
        let width = mesh.bounds.extents.x
        entity.position = [-width / 2, height, 0]
        return entity
    }

    static func make(_ instrument: Instrument) -> Entity {
        let root = Entity()
        root.name = instrument.id
        root.position = instrument.home
        root.components.set(InstrumentComponent(instrumentID: instrument.id, zone: -1))

        switch instrument.id {
        case "getabera":
            // Tall barrel drum
            root.addChild(zone(instrument, index: 0, mesh: .generateCylinder(height: 0.7, radius: 0.15),
                               color: UIColor(red: 0.55, green: 0.12, blue: 0.1, alpha: 1), position: [0, 0, 0]))
            root.addChild(label(instrument.name, height: 0.5))
        case "thammattama":
            // Two short drums side by side: high and low
            root.addChild(zone(instrument, index: 0, mesh: .generateCylinder(height: 0.3, radius: 0.13),
                               color: UIColor(red: 0.45, green: 0.28, blue: 0.14, alpha: 1), position: [-0.17, 0, 0]))
            root.addChild(zone(instrument, index: 1, mesh: .generateCylinder(height: 0.34, radius: 0.16),
                               color: UIColor(red: 0.36, green: 0.22, blue: 0.11, alpha: 1), position: [0.17, 0, 0]))
            root.addChild(label(instrument.name, height: 0.3))
        case "rabana":
            // Wide, flat frame drum tilted towards the player
            root.addChild(zone(instrument, index: 0, mesh: .generateCylinder(height: 0.07, radius: 0.32),
                               color: UIColor(red: 0.78, green: 0.62, blue: 0.4, alpha: 1), position: [0, 0, 0],
                               orientation: simd_quatf(angle: .pi / 3, axis: [1, 0, 0])))
            root.addChild(label(instrument.name, height: 0.42))
        default:
            // Chimes: three golden bells of different heights
            let heights: [Float] = [0.1, 0.0, -0.1]
            for index in 0..<instrument.zoneCount {
                root.addChild(zone(instrument, index: index, mesh: .generateSphere(radius: 0.065 + 0.01 * Float(index)),
                                   color: UIColor(red: 0.95, green: 0.75, blue: 0.2, alpha: 1), metallic: true,
                                   position: [Float(index - 1) * 0.17, heights[index], 0]))
            }
            root.addChild(label(instrument.name, height: 0.22))
        }
        return root
    }
}
