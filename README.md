# SoundSpace

**Play a drum kit and a chord synth all around you.** A visionOS prototype for Apple Vision Pro: a life-size virtual drum kit (kick, snare, hi-hat, two toms, crash and ride on stands) and four chord pads float in your room. Pick a chord progression, let the synth play it, and play the drums on top; record the loop and hear it back. The original Sri Lankan percussion (geta bera, thammattama, rabana, chimes) is a second instrument set you can switch to. Each instrument sounds from where it sits.

SE4041 Mobile Application Design & Development — Assignment 02, Part B.

## Features
- **Instrument sets**: drum kit + chord synth (default) or Sri Lankan percussion
- **Chord synth**: four pads, one per bar of a progression; choose the key, a preset (e.g. I V vi IV) or any of the six chords of the key per bar; chord names float above the pads
- **Control panel** window (glass material, ornament with loop controls): choose instruments, enter/leave the studio, Play/Arrange mode
- **Immersive studio** (`ImmersiveSpace`, mixed): four instruments built from RealityKit primitives, placed within arm's reach
- **Look + pinch** to strike (`SpatialTapGesture` on entities, hover highlight), squash animation
- **Spatial audio**: each playable part has a `SpatialAudioComponent`, so sound comes from the instrument's position
- **Reposition** instruments: Arrange mode, pinch-and-hold and move your hand (clamped to a comfortable zone)
- **4-bar loop recorder** (16 beats, 16th-note quantisation, drift-free playback); the synth plays the chords automatically while you record the drums
- **Interactive rhythm lessons** ("Rock beat" on the drum kit, "First groove" on the Sri Lankan drums): the next drum pulses one beat early; hits are scored by timing
- Unit tests for chords and progressions, the loop recorder, lesson scoring and layout

## Requirements
- Mac with Apple silicon, Xcode 15.2+ (visionOS SDK), **Apple Vision Pro simulator** (Xcode → Settings → Components)
- No third-party packages. [XcodeGen](https://github.com/yonaskolb/XcodeGen) only generates the project (done by GitHub Actions; the generated `SoundSpace.xcodeproj` is committed).

## Build & run
1. `git clone <repo-url>` and open `SoundSpace.xcodeproj`
2. Choose the **Apple Vision Pro** simulator, press **Cmd+R**
3. In the window press **Enter studio**. In the simulator, **click = pinch**. Cmd+U runs the unit tests.
4. If the project file is missing: `brew install xcodegen && xcodegen generate`, or see `Docs/LAB_CHECKLIST.md` Appendix B.

## Sounds
The instrument sounds are **synthesised** by `scripts/make_sounds.py` (pitch-dropping sine tones + noise for drums, inharmonic partials for chimes). They are original, mono WAV files, so there are no licences to cite. Run `python3 scripts/make_sounds.py` to regenerate. They are stylised approximations, not recordings of the real instruments; replacing them with recordings from a drummer is listed as future work.

## Project structure
```
SoundSpace/App/       app entry: window, immersive space
SoundSpace/Core/      pure logic (testable): Instrument, StudioBounds, LoopRecorder, BeatClock, RhythmPattern, LessonScorer
SoundSpace/Studio/    StudioModel (@Observable), InstrumentFactory (RealityKit), SoundBank, InstrumentComponent
SoundSpace/Views/     ControlPanelView (+ornament), StudioImmersiveView
SoundSpace/Resources/ Sounds/*.wav
SoundSpaceTests/      unit tests
Docs/                 technical docs, similar apps, pitch, viva notes
```

## Limitations
Tested in the simulator only (no Vision Pro device): real hand tracking, real spatial-audio perception and performance numbers are unverified. Instruments are simple 3D primitives. One lesson pattern.

## AI assistance
See `AI_LOG.md`.
