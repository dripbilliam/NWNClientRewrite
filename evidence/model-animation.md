# Shared model animation foundation — 2026-10-11

Target: NWN:EE `89.8193.37-17`, x64 PE, existing `../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`. Game assets and the live Ghidra project were read-only throughout this slice; no database annotations were changed.

## Observed target behavior and format evidence

- The previously mapped `Scene::Animate` (`0x1400c5210`) → `Gob::Animate` (`0x14004dbd0`) → `AnimateHierarchy` (`0x14004fe90`) → `MdlNodeControl` (`0x1400926c0`) chain updates part transforms before rendering. See [the original call-chain evidence](rendering-pipeline.md#animated-pose-evaluation).
- Read-only decompilation of `NewController::GetQuaternionValue` (`0x140051530`) confirms four-component controller values, endpoint clamping, and quaternion slerp. `GetVectorValue` (`0x140051750`) confirms three-component values and the high-nibble `0x10` Bezier flag; Bezier rows contain value, incoming relative handle, and outgoing relative handle (nine floats for a vector). The viewer uses those relative handles in its cubic sampler. Scalar sampling is mapped at `0x1400512c0`.
- `RenderSkinned` (`0x1400e0410`, call site `0x1400e0636`) consumes updated hierarchy transforms through `GatherBones` (`0x1400df000`) and `ExecuteSkinGPU` (`0x1400deb90`). The latter uploads at most 64 bone matrices through `RenderInterface::SetBoneMatrix` at `0x1400dee43`. A fresh decompilation confirmed that path; inverse-bind semantics and exceptional slot remapping are still open in this viewer.
- The standard binary MDL animation header/controller layout was cross-checked with the local xoreos primary source `references/xoreos/src/graphics/aurora/model_nwn.cpp` and installed assets. Animation pointers are model-relative; animation headers contain length, transition time, root, and timed events. Controllers have type, row count, time/value indices, and encoded column count. Controller IDs overlap across mesh/light/emitter types, so alpha type 128 is accepted only for mesh nodes.
- Installed ASCII assets use both counted key lists and uncounted lists ending in `endlist`. `ttr_udoor_05` and `pmd0` require the latter. ASCII orientation keys store axis/angle, whereas supported binary orientation keys store quaternion components.

## Implemented replacement behavior

`src/mdl_animation.js` parses bounded binary/ASCII tracks and resolves supermodels with cycle/depth checks and child overrides. Unsupported controllers and unavailable parents become diagnostics; animation failures preserve otherwise valid static geometry. Inherited root node names map onto the child model. Scaling inherited positions by the child/parent animation-scale ratio is **inferred**, rather than established as exact target behavior.

`src/model_animation.js` supplies the common playback clock, rest-pose reset, linear/Bezier/slerp sampling, loops, one-shot completion, and endpoint poses. Bindings are scoped to the owning model, so equipment with repeated node names is not accidentally bound as skeleton nodes. Source coordinates convert from Z-up to Three.js Y-up. Instance alpha materials and skin geometry are independent, while other resources remain shared.

All existing model instance categories use this runtime: tiles, doors, placeables, creatures, attached parts, and standalone models. Attached equipment follows its skeleton anchor even when it has no own clips. The existing mapped-weight skin approximation now runs after bone updates and rebuilds expanded triangle geometry; this is a CPU preview implementation, not target GPU parity. Idle/default clips play when available. The animation panel allows object/clip selection, Play/Pause, elapsed-time/unbound-node inspection, and Focus. Preview playback changes appearance and does not execute gameplay actions or move collision meshes.

`src/door_animation.js` is one consumer of that common runtime. It plays `opening1/2` or `closing1/2`, then selects `opened1/2` or `closed`. During a transition, movement uses the union of old/new DWK states, and repeated interaction is rejected. Completion releases that conservative collision. Diagnostic preview controls are disabled during gameplay transitions so a replaced clip cannot strand the door guard. Missing transition clips select the resting pose immediately; missing resting clips retain the existing collision proxy.

## Validation

### Base opacity correction, 2026-10-11

**Observed in installed assets:** Brogan's Arm uses `t_door01`, `t_door02`, `t_door05`, `ttr_udoor_02` (binary) and `ttr_udoor_05` (ASCII). Each contains a mesh named `sam` with base alpha zero. Binary geometry controller 128 has one column, time 0 and value 0 on that mesh; visible meshes have base alpha 1. The ASCII model explicitly declares `alpha 0`. This interpretation is independently supported by the local xoreos primary source `references/xoreos/src/graphics/aurora/model_nwn.cpp`, its mesh alpha constant and starting-alpha handling. Controller 128 means FPS on emitters, so the geometry parser applies opacity only to mesh nodes.

**Cause and replacement:** base opacity was omitted by the binary parser and ignored during material creation for both formats. The untextured, dark `sam` surface therefore covered the textured door geometry. `binary_mdl.js` now retains mesh base alpha; `model_material.js` applies opacity, visibility, blending and depth policy to binary/ASCII meshes. Animation restores that authored state when a clip omits alpha, and can reveal a base-hidden mesh when an alpha track requests it. Mesh shadow casting now honors its authored shadow flag. No assets or Ghidra annotations were changed.

**Validation:** 57 repository tests pass, including mesh/emitter controller distinction, ASCII zero/fractional opacity and hidden → opaque → restored animation behavior. The installed animation smoke now covers 11 models, including all five Brogan door families, and checks their hidden helper before playback and after reset. The full-scene renderer radial check verifies picking, open/close and menu behavior after the material change; screenshot `backups/animations/door-opacity-fixed.png` is an ignored local capture. Broader material/TXI/shader parity remains open.

- `npm test`: 57 repository tests pass. Animation checks include bounded pools, counted/uncounted ASCII curves, axis conversion, Bezier sampling, independent instances, base opacity/visibility restoration, pause/loop/end behavior, bone-weight/attachment movement, inheritance overrides/cycles, and door collision settlement.
- `npm run build`: passes; the existing large-bundle warning remains.
- `node scripts/smoke-animations.mjs <install> <module>` reads installed Witch's Wake resources directly, samples every clip, checks finite transforms/skin vertices, verifies moving equipment, and runs authored opening/closing collision settlement. No assets are copied into this workspace.

| Model | Clips after inheritance | Clips changing a sampled pose/opacity |
| --- | ---: | ---: |
| `ttr01_t11_01` tile | 4 | 2 |
| `t_door01` | 10 | 5 |
| `t_door02` | 10 | 5 |
| `t_door05` | 10 | 5 |
| `ttr_udoor_02` | 10 | 5 |
| `ttr_udoor_05` ASCII door | 8 | 4 |
| `plc_l01` placeable | 4 | 2 |
| `pmd0` dwarf skeleton | 172 | 168 |
| `pmh0` human skeleton | 172 | 168 |
| `c_deer` | 53 | 42 |
| `c_magetail` mapped skin | 18 | 13 |

Constant resting clips intentionally do not change over time. Inherited human/dwarf clips reference four absent auxiliary nodes across the full clip set (`belt_pelvis`, `lshould_g`, `g_AShTo_011a`, `rshould_g`); present nodes still animate, and the selected clip reports missing bindings.

- Hidden Electron checks in Brogan's Arm verify playback advancement and pause holding for tile, door, placeable, and creature instances, including Angmar's inherited `walk`. The loaded area contains 60 tiles, 29 placeables, 13 doors, 15 creatures, 128 palette-colored parts, and 62 animation-capable instances. Six models report unsupported light/emitter controllers (tile color curves, particle emission/velocity, and chicken effect parameters); transform clips still run. Focus and optional isolation let models inside buildings be inspected without walls obscuring them. Screenshots were inspected locally under ignored `backups/animations/`.

## Still open

This establishes a general animation foundation, not complete animation parity. Light, self-illumination, full emitter/material controllers, animated-mesh vertex/UV tracks, dangly simulation, blending/transition-time semantics, timed-event dispatch/audio, root-motion gameplay, full inverse-bind/slot handling, and gameplay-driven creature actions remain unfinished. The player remains a movement capsule. Exact visual equivalence still needs comparison to authorized in-game moving-pose observations.
