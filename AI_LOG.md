# AI assistance log — SoundSpace

## 2026-10-13 — Analysis, planning and first implementation
**Tool:** Claude (Anthropic), via Claude Code in a claude.ai project
**Prompt (summary):** Same session as SwaraCoach: read the brief and my build guide, plan both apps, then (after my "go") implement them.
**Response summary:** A plan identifying problems in the build guide's visionOS code (an ornament cannot be attached to an immersive space; the drag and tap gestures can conflict; sound lookup by entity name breaks when a child entity is tapped; sound preloading was never called), then the Swift source, unit tests, a sound-synthesis script and docs. The code had **not** been compiled when written.
**Design decisions made with the AI:** Arrange/Play mode switch to avoid tap/drag conflicts; `InstrumentComponent` instead of entity names; loop and lesson logic as pure, tested structs; synthesised sounds instead of downloaded samples; drift-free loop clock.
**What I changed:** *(fill in after the lab session)*
**What I learned:** *(fill in)*

## 2026-10-15 — Drum kit, chord synth and a more realistic kit
**Tool:** Claude (Anthropic), via Claude Code in a claude.ai project
**Prompts (summary):** (1) "Shall we add a drum kit instead of the traditional instruments, and a synthesizer where the user can make a chord progression, play the drums along to those chords and record?" (2) "The drum kit is just cubes and round 3D objects, can I add a realistic drum set, how to do it?"
**Response summary:** (1) A drum kit and a four-bar chord synth with presets, a backing toggle and a loop recorder, with new synthesised sounds, a chord/progression model and unit tests. (2) A procedural kit built from RealityKit primitives (shells, heads, hoops, lugs, stands, pedal, cymbals) plus a floor tom and ride, and the option of a downloaded USDZ model.
**Design decisions made with the AI:** Chords and progressions as pure tested structs; one drift-free 16th-note loop clock shared by backing chords and recording; primitives only, to avoid APIs that could not be compiled in the cloud; then, at my request, removed the Sri Lankan percussion so the app has only the drum kit and chord synth (its code, sounds, tests and docs).
**What I changed:** *(fill in after running it in the simulator)*
**What I learned:** *(fill in)*

## Template
```
## DATE — topic
Tool: / Prompt: / Response summary: / What I changed: / What I learned:
```
