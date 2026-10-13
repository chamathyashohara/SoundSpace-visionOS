# SoundSpace — Technical Documentation

## 1. Scenes (visionOS capabilities used)
| Scene | Type | Purpose |
|---|---|---|
| Control panel | `WindowGroup` | SwiftUI window with glass look; instrument toggles, studio entry, mode, loop and lesson controls; an **ornament** (`TransportBar`) with record/play/stop under the window |
| Studio | `ImmersiveSpace(id: "studio")`, `.mixed` | RealityKit scene: instruments appear in the user's real room |

## 2. Architecture
`StudioModel` (`@MainActor @Observable`) is the single source of truth; the views are thin. Pure logic (`Core/`) has no RealityKit dependency and is unit tested: `Instrument`, `StudioBounds`, `LoopRecorder`, `BeatClock`, `RhythmPattern`, `LessonScorer`, `StudioLayout`. RealityKit code is isolated in `InstrumentFactory`, `SoundBank` and the strike/pulse animation methods.

## 3. Entities and interaction
Each instrument is a root `Entity` (component `InstrumentComponent(zone: -1)`) with child `ModelEntity` parts, one per playable zone (geta bera 1, thammattama 2, rabana 1, chimes 3). Each part has `InputTargetComponent` + collision shapes (needed for gaze-and-pinch), `HoverEffectComponent` (system highlight when looked at), `SpatialAudioComponent` (sound emitted from its position) and `InstrumentComponent(zone: n)`.
- **Strike:** `SpatialTapGesture().targetedToAnyEntity()` → `StudioModel.handleTap` → plays the preloaded `AudioFileResource` on that entity (`entity.playAudio`) and animates a squash (`entity.move(to:)`).
- **Reposition:** in *Arrange* mode `DragGesture().targetedToAnyEntity()` moves the **root** entity (found by walking up the parents); position is clamped by `StudioBounds` (x ±1.2 m, y 0.5–1.8 m, z −1.6…−0.35 m) so instruments stay within reach. Separate Play/Arrange modes avoid the conflict between tap and drag on the same entity.
- **Why a component instead of `entity.name`:** a tap can land on a child; the component maps any part back to its instrument and zone.

## 4. Spatial audio
Sound files are mono 16-bit WAV (stereo files are not spatialised). `SoundBank.preload()` loads all of them once so a pinch plays with no delay. The sounds are synthesised by `scripts/make_sounds.py`.

## 5. Loop recorder
`LoopRecorder`: 8 beats × 4 steps = 32 steps. `quantize(beat:)` rounds a time position to the nearest step and wraps at the end (beat 2.97 → step 12; beat 7.9 → step 0). Recording takes exactly 8 beats at the chosen tempo, then playback starts automatically. Playback runs `Task.sleep(until:)` against absolute deadlines from a `ContinuousClock` origin, so timing does not drift over repeated loops. During playback the hits call `strike(record: false)`.

## 6. Rhythm lesson
`RhythmPattern.firstGroove` (8 hits over 8 beats, 80 bpm) after a 4-beat count-in. Each upcoming drum **pulses one beat early** (`pulse`), the control panel says "Next: …". When it ends `LessonScorer.score` matches each expected hit to the closest unused played hit on the same zone within ±250 ms and reports accuracy, average timing error and extra hits.

## 7. Platform design guidance followed
Content within 0.6–1.2 m of the user, nothing head-locked, glass materials, hover effects, mixed immersion (the room stays visible), always-visible way out (*Leave studio* button; Digital Crown), controls placed in the window/ornament where they are easy to reach.

## 8. Performance
Sounds preloaded; entities created once; no materials created on a hit (only a scale animation); loop timing driven by the continuous clock. **[Add simulator observations: smooth interaction, CPU in Xcode gauge.]** Device performance (90 fps) is unverified without a Vision Pro.

## 9. Testing
`SoundSpaceTests` (15 tests): quantisation and wrap-around, duplicate hits, beat clock, lesson scoring (perfect play, timing window, wrong zone, one-to-one matching), pattern validity, default layout spacing and reach, bounds clamping. Manual test script: Enter studio → click each part (sound + squash) → Arrange and drag → Record 5 s → loop plays → Start lesson → result appears.

## 10. Limitations / future work
Simulator-only testing; primitives instead of modelled instruments; synthesised, not recorded, sounds; one lesson; SharePlay jam and hand-tracking strikes not implemented; iPad/iPhone AR port.
