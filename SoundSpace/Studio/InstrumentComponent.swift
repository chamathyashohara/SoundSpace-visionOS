import RealityKit

/// Attached to every instrument entity so a tapped/dragged entity can be mapped back to its instrument.
/// `zone == -1` marks the instrument's root (what gets dragged); zones 0... are the parts that make sound.
struct InstrumentComponent: Component {
    var instrumentID: String
    var zone: Int

    var key: String { Instrument.key(instrumentID, zone: zone) }
    var isRoot: Bool { zone < 0 }
}
