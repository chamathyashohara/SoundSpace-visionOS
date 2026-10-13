# AI assistance log — SoundSpace

## 2026-10-13 — Analysis, planning and first implementation
**Tool:** Claude (Anthropic), via Claude Code in a claude.ai project
**Prompt (summary):** Same session as SwaraCoach: read the brief and my build guide, plan both apps, then (after my "go") implement them.
**Response summary:** A plan identifying problems in the build guide's visionOS code (an ornament cannot be attached to an immersive space; the drag and tap gestures can conflict; sound lookup by entity name breaks when a child entity is tapped; sound preloading was never called), then the Swift source, unit tests, a sound-synthesis script and docs. The code had **not** been compiled when written.
**Design decisions made with the AI:** Arrange/Play mode switch to avoid tap/drag conflicts; `InstrumentComponent` instead of entity names; loop and lesson logic as pure, tested structs; synthesised sounds instead of downloaded samples; drift-free loop clock.
**What I changed:** *(fill in after the lab session)*
**What I learned:** *(fill in)*

## Template
```
## DATE — topic
Tool: / Prompt: / Response summary: / What I changed: / What I learned:
```
