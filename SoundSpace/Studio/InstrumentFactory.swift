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


    // MARK: Drum kit

    private static let chrome = UIColor(white: 0.82, alpha: 1)
    private static let brass = UIColor(red: 0.86, green: 0.68, blue: 0.26, alpha: 1)
    private static let drumHead = UIColor(red: 0.96, green: 0.95, blue: 0.9, alpha: 1)
    private static let shellRed = UIColor(red: 0.55, green: 0.05, blue: 0.08, alpha: 1)
    /// Y position of the floor inside the kit's own coordinates (the kit root sits 0.85 m above the floor).
    private static let floorY: Float = -0.85

    /// A non-playable decoration piece (hardware, rims, heads, lugs).
    private static func part(_ mesh: MeshResource, _ color: UIColor, metallic: Bool = false,
                             position: SIMD3<Float>, orientation: simd_quatf = .init(angle: 0, axis: [0, 1, 0])) -> ModelEntity {
        let entity = ModelEntity(mesh: mesh, materials: [material(color, metallic: metallic)])
        entity.position = position
        entity.orientation = orientation
        return entity
    }

    /// A thin metal tube between two points (stand legs, pedal arms, tom mounts).
    private static func rod(from a: SIMD3<Float>, to b: SIMD3<Float>, radius: Float = 0.008) -> ModelEntity {
        let direction = b - a
        let length = simd_length(direction)
        return part(.generateCylinder(height: length, radius: radius), chrome, metallic: true,
                    position: (a + b) / 2, orientation: simd_quatf(from: [0, 1, 0], to: simd_normalize(direction)))
    }

    /// A drum: the shell is the playable zone; the head, hoops and lugs are children, so they squash and pulse with it.
    private static func drum(_ instrument: Instrument, index: Int, radius: Float, height: Float, shell: UIColor,
                             metallicShell: Bool = false, position: SIMD3<Float>,
                             orientation: simd_quatf = .init(angle: 0, axis: [0, 1, 0])) -> ModelEntity {
        let body = zone(instrument, index: index, mesh: .generateCylinder(height: height, radius: radius),
                        color: shell, metallic: metallicShell, position: position, orientation: orientation)
        body.addChild(part(.generateCylinder(height: 0.006, radius: radius * 0.97), drumHead,
                           position: [0, height / 2 + 0.004, 0]))                                   // batter head
        for side: Float in [1, -1] {
            body.addChild(part(.generateCylinder(height: 0.016, radius: radius + 0.009), chrome, metallic: true,
                               position: [0, side * (height / 2 - 0.004), 0]))                      // hoops
        }
        for lug in 0..<6 {
            let angle = Float(lug) * .pi / 3
            body.addChild(part(.generateBox(size: [0.018, height * 0.55, 0.018]), chrome, metallic: true,
                               position: [(radius + 0.008) * cos(angle), 0, (radius + 0.008) * sin(angle)]))
        }
        return body
    }

    /// A cymbal: a thin brass disc with a bell in the middle. The disc is the playable zone.
    private static func cymbal(_ instrument: Instrument, index: Int, radius: Float, position: SIMD3<Float>,
                               tilt: Float) -> ModelEntity {
        let disc = zone(instrument, index: index, mesh: .generateCylinder(height: 0.02, radius: radius),
                        color: brass, metallic: true, position: position,
                        orientation: simd_quatf(angle: tilt, axis: [1, 0, 0]))
        disc.addChild(part(.generateSphere(radius: radius * 0.2), brass, metallic: true, position: [0, 0.012, 0]))
        return disc
    }

    private static func addDrumKit(to root: Entity, instrument: Instrument) {
        let facing = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])      // lays a drum on its side, head towards you

        // Kick drum, on its side, with a pedal and beater on your side and two legs at the front.
        let kickPosition = SIMD3<Float>(0, -0.62, -0.1)
        root.addChild(drum(instrument, index: 0, radius: 0.22, height: 0.4, shell: shellRed, position: kickPosition, orientation: facing))
        root.addChild(part(.generateBox(size: [0.09, 0.012, 0.24]), chrome, metallic: true, position: [0, floorY + 0.006, 0.3]))
        root.addChild(rod(from: [0, floorY + 0.02, 0.26], to: [0, -0.62, 0.12], radius: 0.01))
        root.addChild(part(.generateSphere(radius: 0.028), UIColor(white: 0.2, alpha: 1), position: [0, -0.62, 0.115]))
        for side: Float in [1, -1] {
            root.addChild(rod(from: [side * 0.12, -0.5, -0.28], to: [side * 0.2, floorY, -0.36]))
        }

        // Snare on a stand, tilted slightly towards you.
        let snarePosition = SIMD3<Float>(-0.14, -0.27, 0.22)
        root.addChild(drum(instrument, index: 1, radius: 0.15, height: 0.12, shell: chrome, metallicShell: true,
                           position: snarePosition, orientation: simd_quatf(angle: 0.12, axis: [1, 0, 0])))
        root.addChild(rod(from: [snarePosition.x, floorY, snarePosition.z], to: [snarePosition.x, snarePosition.y - 0.07, snarePosition.z]))
        for leg in 0..<3 {
            let angle = Float(leg) * 2 * .pi / 3 + .pi / 6
            root.addChild(rod(from: [snarePosition.x, floorY + 0.25, snarePosition.z],
                              to: [snarePosition.x + 0.13 * cos(angle), floorY, snarePosition.z + 0.13 * sin(angle)], radius: 0.006))
        }

        // Hi-hat: two cymbals on a tall stand with a foot pedal. The top one is the playable zone.
        let hatPosition = SIMD3<Float>(-0.6, 0.05, 0.1)
        root.addChild(cymbal(instrument, index: 2, radius: 0.15, position: hatPosition, tilt: 0.04))
        root.addChild(part(.generateCylinder(height: 0.012, radius: 0.15), brass, metallic: true,
                           position: [hatPosition.x, hatPosition.y - 0.03, hatPosition.z]))
        root.addChild(rod(from: [hatPosition.x, floorY, hatPosition.z], to: [hatPosition.x, hatPosition.y + 0.03, hatPosition.z]))
        root.addChild(part(.generateBox(size: [0.08, 0.02, 0.2]), chrome, metallic: true,
                           position: [hatPosition.x, floorY + 0.01, hatPosition.z + 0.12]))

        // Rack tom mounted above the kick.
        let rackPosition = SIMD3<Float>(-0.1, -0.1, -0.12)
        root.addChild(drum(instrument, index: 3, radius: 0.125, height: 0.13, shell: shellRed, position: rackPosition,
                           orientation: simd_quatf(angle: 0.35, axis: [1, 0, 0])))
        root.addChild(rod(from: [rackPosition.x, -0.4, -0.18], to: [rackPosition.x, rackPosition.y - 0.07, rackPosition.z - 0.02], radius: 0.01))

        // Floor tom on three legs.
        let floorTomPosition = SIMD3<Float>(0.5, -0.3, 0.05)
        root.addChild(drum(instrument, index: 5, radius: 0.19, height: 0.3, shell: shellRed, position: floorTomPosition,
                           orientation: simd_quatf(angle: 0.08, axis: [1, 0, 0])))
        for leg in 0..<3 {
            let angle = Float(leg) * 2 * .pi / 3 + .pi / 2
            root.addChild(rod(from: [floorTomPosition.x + 0.17 * cos(angle), floorTomPosition.y - 0.1, floorTomPosition.z + 0.17 * sin(angle)],
                              to: [floorTomPosition.x + 0.19 * cos(angle), floorY, floorTomPosition.z + 0.19 * sin(angle)], radius: 0.01))
        }

        // Crash (left, high) and ride (right) on boom stands.
        let crashPosition = SIMD3<Float>(-0.5, 0.45, -0.2)
        root.addChild(cymbal(instrument, index: 4, radius: 0.2, position: crashPosition, tilt: 0.2))
        root.addChild(rod(from: [crashPosition.x, floorY, crashPosition.z], to: [crashPosition.x, crashPosition.y - 0.02, crashPosition.z]))
        let ridePosition = SIMD3<Float>(0.3, 0.2, -0.3)
        root.addChild(cymbal(instrument, index: 6, radius: 0.24, position: ridePosition, tilt: 0.12))
        root.addChild(rod(from: [ridePosition.x, floorY, ridePosition.z], to: [ridePosition.x, ridePosition.y - 0.02, ridePosition.z]))

        root.addChild(label(instrument.name, height: 0.72))
    }

    static func make(_ instrument: Instrument) -> Entity {
        let root = Entity()
        root.name = instrument.id
        root.position = instrument.home
        root.components.set(InstrumentComponent(instrumentID: instrument.id, zone: -1))

        switch instrument.id {
        case "drumkit":
            addDrumKit(to: root, instrument: instrument)
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
            break
        }
        return root
    }
}
