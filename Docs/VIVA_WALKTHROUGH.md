# Viva walkthrough — SoundSpace

## 60-second story
"Sri Lankan drums like the geta bera are expensive, loud and hard to access, and there are almost no digital versions. SoundSpace puts life-size drums and chimes around you on Apple Vision Pro. You look at one and pinch to play it, and it sounds from where it sits. You can move them, record an 8-beat loop, and follow a rhythm lesson."

## Files
| File | Say this |
|---|---|
| `App/SoundSpaceApp.swift` | A window for controls and an `ImmersiveSpace` for the studio; mixed immersion keeps your room visible. `InstrumentComponent` is registered so RealityKit knows it. |
| `Core/Instrument.swift` | Instrument data, default positions in metres (negative z = in front), bounds that keep things within reach. |
| `Core/Rhythm.swift` | `BeatClock` converts beats↔seconds; `LoopRecorder` quantises to a 16th-note grid and wraps; `LessonScorer` matches played hits to expected hits within ±250 ms. |
| `Studio/InstrumentFactory.swift` | Builds drums from cylinders and chimes from spheres; each playable part gets input-target, collision, hover-effect and spatial-audio components. |
| `Studio/StudioModel.swift` | Single source of truth; strike plays sound + squash; drag moves the root entity; loop uses absolute deadlines (no drift); lesson pulses the next drum a beat early. |
| `Views/StudioImmersiveView.swift` | `RealityView` + gestures targeted to entities (`SpatialTapGesture`, `DragGesture`). |
| `Views/ControlPanelView.swift` | SwiftUI window; opens/closes the immersive space; ornament. |

## Likely questions
- **What makes it spatial, not just 3D?** Immersive space in your room, gaze-and-pinch input, per-instrument spatial audio, hands reposition objects.
- **Why a separate Arrange mode?** Pinch-tap and pinch-drag on the same entity can conflict; separate modes make intent explicit.
- **How do you keep timing accurate?** Preloaded sounds; loop uses a continuous clock with absolute deadlines.
- **Why not just an iPad app?** Real scale, sound from the right place, drumming motion — and the pitch's plan includes an iPad AR port.
- **Who pays first / how do you get authentic rhythms?** See the pitch: schools, museums, cultural bodies; partner with a music academy and record real drummers.
- **Limitations?** Simulator only; stylised synthesised sounds; primitives for models.
