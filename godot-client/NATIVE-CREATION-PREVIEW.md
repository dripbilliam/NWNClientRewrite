# Native original-model appearance preview

Status: **appearance preview core locally verified; complete creator/UI migration
and rendering/performance parity remain incomplete**. Only the owned local server
was used. No Arelith connection or public server discovery was made.

The Appearance page now has an isolated native3D viewport beside the controls.
It displays the original body, attached parts, head, clothing, palette colors and
idle animation. It rotates automatically; dragging pauses automatic rotation,
the wheel zooms, and Reset view restores framing. Retry repeats preparation for
the current private appearance choice. Controls remain usable during preparation.

The staging adapter reuses `loadCharacterCreationAssets`, the original model/
texture/palette importer, hierarchy builder and animator bindings. Its resolver
retains the native texture-resource lookup priority, including active custom
content. Only the nine appearance fields and five relevant active tables cross
to that preparer. Names, biography, credentials and client-supplied resource paths
are not part of the preview request.

Creation body parts keep their physical bone parents and full P/Q/scale. Their
export path is distinct from the sibling-root reference/VFX attachment path;
existing effect-model validation remains strict. The complete original geometry,
UVs and decoded texture pixels are preserved. The preview transfers its selected
original idle clip; the rest of the model's animation library is unnecessary for
this control. Godot owns the viewport, camera, rotation, model clocks and skinning.
No browser renderer or network object is driven for preview animation.

The original idle/rig metadata and GLB travel through bounded128KiB chunks with
independent sizes, ordering, owner IDs and SHA256. Godot checks both parts and the
expected appearance before importing the in-memory GLB. There are no runtime
preview asset files in the workspace. A private local rig handle0 never enters
the canonical gameplay registry, collision, picking or world movement maps.

Preparation is serialized; later edits replace queued work, and late results
cannot replace a newer appearance. Up to eight results/32MiB are cached within
the active rule owner. Opening a palette without changing the appearance reuses
the current preview. Staging geometry/material/texture owners release after each
export, including exceptions. Replacement, page change, creator close, admission
and reconnect retire native model/rig/skeleton owners and chunk buffers. Backend
retirement drains jobs and releases cached bytes.

## Evidence

- `reports/native-appearance-creation-local-v2.json`: **61 live local checks**.
  Four actual male-dwarf previews cover original head and clothing changes and
  skin palette row10. Original idle advances20 native part transforms and its
  clock; automatic rotation advances without another transfer. Palette browsing
  retains the same model, while choosing a color changes the actual GLB/texture
  bytes. Previous native model owners are freed and transfer buffers released.
  Original voice playback, canonical appearance/soundset exports, saved-character
  reconnect and **two moving/animated world admissions** also pass. Native exit0,
  no script/engine errors, zero retired preview jobs/cache bytes. Rendering was
  reviewed in `reports/native-appearance-creation-local-v2-appearance.png`.
- The earlier full-library run, `native-appearance-creation-local-v1`, also passes
  61 checks. Each preview originally transferred7.14–7.21MB. The accepted idle
  profile transfers0.96–1.03MB: **85.7–86.5% smaller**. All four GLB hashes are
  identical between those runs, proving the geometry/texture payload was unchanged
  by this metadata reduction. This is a transfer-size result, not a60FPS claim.
- `reports/creation-preview-rendered-v1.json`: **19 actual Vulkan checks**, clean
  engine log. Authored meshes exercise native skin deformation, idle clocks,
  nested full-scale body-part parenting against the independent original hierarchy
  oracle, camera controls, replacement, corrupted-transfer rejection and cleanup.
  The existing VFX class still rejects the creator envelope. No installed game
  assets are serialized by this authored fixture.
- `reports/preview-native-headless-v1.json`: **18 authored checks**, clean log.
  Pose/clock checks are explicitly separate from GPU skin readback because the
  Dummy renderer does not register GPU skeletons.
- Creator/audio/browser/lobby GUI regressions pass **16 /19 /22 /20** checks in
  `preview-creator-ui-regression-v1`, `preview-audio-ui-regression-v1`,
  `preview-browser-ui-regression-v1` and `preview-lobby-ui-regression-v1`.
- `reports/native-preview-node-regression-v1.log`: **164 tests pass**, no failures
  or skips. Includes nested ownership and exact source pixel/UV checks, idle-only
  selection, bounded transport/cache, replaced rule contexts, queued edit
  coalescing, stale preparation, exception cleanup and existing visual/rig/
  creator/audio/browser/settings/lobby/level-up regressions.

Rejected development reports remain distinct. An initial test declaration needed
an explicit transform type. A headless probe incorrectly attempted GPU skin
readback; headless and rendered evidence are now separate. A corrupt-transfer test
also found that subsequent packets could overwrite its failure status; that owner
now remains failed until a new appearance starts. Those reports are not accepted.

## Remaining

Broader race/gender/phenotype/custom clothing/head/mount/reference combinations,
skin/alpha/texture edge cases, exhaustive palette coverage, physical-device and
accessibility acceptance, low-resolution layouts, creator help/descriptions and
original font/skin fidelity remain open. Appearance lighting uses the native
engine under the user's accepted visual-difference allowance. Existing world
particle missing-resource/fidelity diagnostics remain unresolved. Full world
rendering, combat, audio, public multiplayer/handoffs, single-player and sustained
moving-scene60FPS acceptance are separate outstanding migration requirements.
