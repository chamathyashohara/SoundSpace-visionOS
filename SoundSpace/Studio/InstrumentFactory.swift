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

    /// Horizontal position of each chord pad inside the synth, left to right.
    static let chordPadX: [Float] = [-0.45, -0.15, 0.15, 0.45]
    static let chordLabelPrefix = "chordlabel#"

    /// Re-writes the chord name floating above a pad (called whenever the progression changes).
    static func updateChordLabel(_ entity: Entity, slot: Int, text: String) {
        guard let model = entity as? ModelEntity, slot >= 0, slot < chordPadX.count else { return }
        let mesh = MeshResource.generateText(text, extrusionDepth: 0.004, font: .systemFont(ofSize: 0.09, weight: .bold))
        model.model?.mesh = mesh
        model.position = [chordPadX[slot] - mesh.bounds.extents.x / 2, 0.15, 0.03]
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
        case "drumkit":
            // Kick lies on its side facing you; snare and tom in front, hi-hat on the left, crash on the right.
            root.addChild(zone(instrument, index: 0, mesh: .generateCylinder(height: 0.3, radius: 0.22),
                               color: UIColor(red: 0.5, green: 0.08, blue: 0.1, alpha: 1), position: [0, -0.3, -0.05],
                               orientation: simd_quatf(angle: .pi / 2, axis: [1, 0, 0])))
            root.addChild(zone(instrument, index: 1, mesh: .generateCylinder(height: 0.1, radius: 0.15),
                               color: UIColor(white: 0.85, alpha: 1), metallic: true, position: [-0.22, 0.02, 0.15]))
            root.addChild(zone(instrument, index: 2, mesh: .generateCylinder(height: 0.02, radius: 0.15),
                               color: UIColor(red: 0.95, green: 0.78, blue: 0.25, alpha: 1), metallic: true, position: [-0.62, 0.2, 0],
                               orientation: simd_quatf(angle: .pi / 14, axis: [1, 0, 0])))
            root.addChild(zone(instrument, index: 3, mesh: .generateCylinder(height: 0.14, radius: 0.13),
                               color: UIColor(red: 0.12, green: 0.25, blue: 0.5, alpha: 1), position: [0.15, 0.22, -0.08],
                               orientation: simd_quatf(angle: .pi / 12, axis: [1, 0, 0])))
            root.addChild(zone(instrument, index: 4, mesh: .generateCylinder(height: 0.015, radius: 0.22),
                               color: UIColor(red: 0.95, green: 0.78, blue: 0.25, alpha: 1), metallic: true, position: [0.6, 0.5, -0.05],
                               orientation: simd_quatf(angle: .pi / 12, axis: [1, 0, 0])))
            root.addChild(label(instrument.name, height: 0.72))
        case "chordpads":
            // Four coloured pads tilted towards you, each with its chord name above it.
            for index in 0..<instrument.zoneCount {
                let color = UIColor(hue: 0.08 + 0.2 * CGFloat(index), saturation: 0.65, brightness: 0.9, alpha: 1)
                root.addChild(zone(instrument, index: index, mesh: .generateBox(size: [0.26, 0.18, 0.06], cornerRadius: 0.03),
                                   color: color, position: [chordPadX[index], 0, 0],
                                   orientation: simd_quatf(angle: -.pi / 10, axis: [1, 0, 0])))
                let text = ModelEntity(mesh: .generateText("–", extrusionDepth: 0.004, font: .systemFont(ofSize: 0.09, weight: .bold)),
                                       materials: [UnlitMaterial(color: .white)])
                text.name = "\(chordLabelPrefix)\(index)"
                root.addChild(text)
                updateChordLabel(text, slot: index, text: "–")
            }
            root.addChild(label(instrument.name, height: 0.3))
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
