# Native systems milestone

All implementation lives in this top-level project. The original client and
normal application bundle remain unchanged. No Arelith connection was made.

Implemented in native Godot:

- An 898-object registry retaining source IDs, resolved names, model references,
  controlled-character identity, reaction colors and eligibility. Multi-part
  bodies/equipment resolve to the same logical object. Source geometry and
  textures are not replaced by proxy artwork.
- Exact triangle picking with scenery occlusion, hover selection, hand cursor,
  colored multi-part highlights, and hold-Tab highlighting/nameplates. Geometry
  is imported once for physics; meshes/UVs remain unchanged.
- Middle-mouse orbit, wheel zoom, normalized WASD inspection-camera pan,
  Shift speed and Home reset. Middle orbit works with menus open; focus loss
  releases capture and held selection input. WASD is not yet server-authorized
  character movement.
- Read-only native object details, a captured-object list and controls panel.
  Multiple menus can be open, dragged and raised; their positions are saved on
  drag release. Menu rectangles block pointer selection while clicks outside
  retain world access. Nameplates render behind menus. Text has dark borders
  and panels have opaque dark backgrounds.
- Correct mix/additive material selection for all 115 imported particle meshes,
  preserving original texture references and disabling particle depth writes.
  The 114 additive particle meshes no longer show the previous black quads.
  Their simulation and billboard poses remain frozen.

Run from the workspace:

```powershell
.\godot-client\run.ps1
```

The launcher uses `.cache/latest-room.json`, a pointer to the external captured
bundle, and makes no server connection. If the OS removes the temporary bundle,
export again or pass `-Scene` with a valid external GLB/manifest pair.

Controls: middle drag / wheel / WASD / Shift / Home; left click selects, right
click or I opens details; hold Tab highlights; F1 controls, F2 object list,
F3 performance overlay. Actor movement, actual object actions, inventory,
spellbook, NUI, animation and the live networking bridge still require migration.

The separate `join-local.ps1` launcher now supplies a live connection and basic
movement/actions/chat/conversations. The controls above describe `run.ps1`'s
offline mode. See [LOCAL-MULTIPLAYER.md](LOCAL-MULTIPLAYER.md) for the live mode,
its validation and its remaining limitations.

Validation:

- Seven Node transfer/regression checks pass.
- Twenty-three native authored checks pass: identity, texture-preserving blend
  adaptation, multi-part highlight restoration, occluded triangle rays, camera
  movement/reset/clamping, simultaneous menus, pointer blocking, middle orbit
  with menus, focus release, CPU importer arrays, and mirrored/nonuniform
  indexed geometry. Report: `reports/systems-authored-v4.json`.
- Full-room native Vulkan smoke passes with all 4,145 source mesh nodes,
  2,834 entity-bound parts, 4,030 physics surfaces and 115 particle materials.
  Missing bindings/material failures: zero. A real door ID 2147625690 was picked
  and inspected while three menus stayed open. Reports/screenshots:
  `reports/systems-room-v1.*` and `reports/systems-room-v2.*`.
- First physics setup regressed loading to 39,148 ms. Reusing CPU-resident
  ImporterMesh arrays eliminated all 4,030 renderer geometry readbacks. The
  corrected run loaded in 6,577 ms, including 282 ms of native registry/picking
  preparation. It retained every mesh and physics surface. This is an observed
  before/after diagnostic, not a repeated loading benchmark.

The 180-frame systems smoke includes intentional camera/UI changes and reports
~23.81 ms mean / 39.83 ms p95. It is not a controlled gameplay FPS comparison,
does not meet the 60 FPS target and does not complete the broader goal. The
import's remaining mip, animation, effect and gameplay gaps remain explicit.

The local-server launcher now has native model transform playback and GPU
skinning. The offline import figures above remain historical frozen-scene
measurements. See [NATIVE-MODELS.md](NATIVE-MODELS.md) for the animated local
checks, original-handle curve transfer and remaining model/controller gaps.
