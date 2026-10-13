import Foundation
import simd

enum StudioLayout {
    /// True when no two instruments are closer than `minimumDistance` metres (so they never overlap).
    static func isSpacedOut(_ instruments: [Instrument], minimumDistance: Float = 0.35) -> Bool {
        for (index, a) in instruments.enumerated() {
            for b in instruments.dropFirst(index + 1) where simd_distance(a.home, b.home) < minimumDistance { return false }
        }
        return true
    }

    /// Distance from the user (standing at x = 0, z = 0, head height 1.6 m) to a position.
    static func distanceFromUser(_ p: SIMD3<Float>) -> Float {
        simd_distance(p, SIMD3<Float>(0, 1.6, 0))
    }
}
