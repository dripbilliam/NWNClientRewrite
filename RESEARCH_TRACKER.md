# Research Tracker

## Final combat modifier checkpoint: 2026-10-12

Native script-visible AC, nominal melee/offhand/ranged bonuses, final saving-throw modifiers and positive stat effects now read shared character/canonical equipment state. Application, deferred removal, strict expiry and XP rollback refresh the same records; unsupported item execution and effect presentation are persisted. 159 tests, build, bundled character UI and authored-startup/diagnostic checks pass. Under both Prelude and Witch's Wake, AC matches all 39 BIC snapshots and final saves match 38; the Weapon Master save discrepancy remains explicit. Opponent-specific AC/attack, immunity-aware decreases, temporary ability effects, real equip/unequip and a native runtime oracle precede melee resolution. Combat/server parity is not established. See [Final modifier evidence and native callsites](evidence/combat-final-modifiers.md).

## Base combat stat checkpoint: 2026-10-12

Native class/history/epic base attack and saving throws, exact save feat constants, ruleset hashing/cache/defaults and ability modifier arithmetic now drive shared PC state and base character-sheet values. 141 tests pass. All 39 installed BICs load under Prelude and Witch's Wake; all 17 attack snapshots match, while eight partial save discrepancies remain explicit. Bundled UI and real startup rollback checks pass with persistent missing-call diagnostics. Final modifiers, armor class, combat resolution, independent native runtime differential validation and server interoperability remain open. See [Base combat providers and native callsites](evidence/combat-stat-providers.md).

## Combat/interoperability requirement: 2026-10-12

The replacement must run alongside original clients with nearly identical combat. The roadmap now treats interoperability as required and separates local resolution from server-authoritative network state. Every claimed combat slice needs native evidence and differential validation of rules, action/round/event order, consequences and presentation; approximate outcomes or self-derived expected values cannot establish parity. This is an acceptance requirement, not a claim that combat or the protocol is implemented. See [Combat compatibility contract](evidence/combat-compatibility-contract.md).

## Runtime diagnostic checkpoint: 2026-10-12

Replacement-client instrumentation now retains encountered missing/failed engine calls and resource/render/UI/audio omissions, with canonical IDs and available script/module/area/resource context. Per-run native JSONL files and browser IndexedDB retain the complete journal beyond the short HUD message buffer. 130 tests pass; real startup files/exports capture CopyObject and EffectDamage, radial/door fixtures retain placeholders and omissions, and browser history survives reload. See [Runtime diagnostic evidence](evidence/runtime-diagnostics.md). The shared rules validation milestone remains next; no native game behavior was inferred or altered for this instrumentation.

## Player BIC/XP checkpoint: 2026-10-11

Real PC import preserves the canonical actor record and assigns fresh IDs to inventory/equipment, including nested contents. Character/skill/feat/spell/equipment panels, portrait, body assembly and HP/XP now read imported state. Native character, PC HP, equipped ability modifiers and positive XP award paths were mapped in Ghidra plus complete read-only PE disassembly. All 39 installed player BICs parse; 38 HP snapshots match the default mapped calculation, with one Pale Master discrepancy retained as open. Brogan's compiled script awards 100 XP once. 89 unit tests and the full GUI/character/scripted-door renderer check pass. See [Character evidence and limitations](evidence/player-character.md).

## Gameplay UI checkpoint: 2026-10-11

Shared native GUI/MDL/font presentation covers the 104-layout installed catalog. The gameplay HUD, journal text/completion, notes, quickbar references and examination are connected to module state; remaining panel families/front-end workflows expose explicit engine placeholders. Native journal page setup and current quickbar models were checked in Ghidra. See [UI evidence, validation and open work](evidence/game-ui.md).

## Milestone 0: Reproducible target baseline

**Status: Complete**

- Target is NWN:EE `89.8193.37-17`, x64 PE.
- SHA-256 recorded in `README.md`; source manifest is `../FullDecomp/ghidra-projects/nwmain.sha256.txt`.
- Ghidra 11.3.2 project exists at `../FullDecomp/ghidra-projects/NWN-EE-8193.37-17.gpr`.
- At initial setup, the Ghidra process was running and its local MCP HTTP endpoint returned successfully.
- No binary or Ghidra database changes were made for this setup.
- SHA-256 and file-version inventory recorded for the installed Windows executables in `evidence/binary-inventory.md`.

## Milestone 1: Static architecture map

**Status: In progress**

- [x] Identify the graphics API from imports.
- [x] Trace WGL library loading and bootstrap-context setup.
- [x] Find a concrete geometry-submission function and inspect its decompilation.
- [x] Find the imported frame-present call and inspect its direct caller.
- [x] Trace object transforms into mesh collection and draw-bucket dispatch.
- [x] Resolve the concrete PartTriMesh virtual draw target and its vertex/index data path.
- [x] Trace model attributes into GPU buffer upload and indexed draw calls.
- [x] Trace shader/buffer procedure loading and bitmap-backed mesh materials.
- [x] Map stock shader reload, source loading, attribute-based selection, and uniform upload paths.
- [x] Trace PartSkin through bone gathering, 64-slot matrix upload, and the skinned vertex-shader draw path.
- [x] Trace PartSkin::PostProcess bone-name remapping through vIndex/vWeight pools to the stock GLSL weighted-matrix equation.
- [x] Trace normal WGL context creation and activation.
- [x] Trace Camera::RenderScene through Scene::Render into RenderSinglePass.
- [x] Record the ordered scene bucket/render passes.
- [x] Map application shutdown through renderer cleanup, SDL_Quit, SDL video-device teardown, and SDL window destruction.
- [x] Map the SDL_main application loop, per-frame Update ordering, overlay pass, and renderer shutdown call.
- [x] Connect the client frame worker through CGuiMan/CSceneView to Camera::RenderScene, Scene::Render, and RenderSinglePass.
- [x] Trace RenderInterface::SwapBuffers through SDL_GL_SwapWindow, the active video device, SwapWindowBuffers, and Win32 SwapBuffers.
- [x] Map engine animation runs, controller interpolation, Part hierarchy updates, and animated skin-matrix consumption.
- [x] Map SDL window/HDC teardown and verify the registered context-delete callback calls wglDeleteContext.
- [x] Identify gameplay rendering independently of GUI CSceneView: client worker -> FUN_140767d50 -> module update -> module camera -> Camera::RenderScene.
- [x] Verify active-area Scene::Animate executes before the gameplay camera renders.
- [ ] Validate renderer teardown: pool buffers have no observed glDeleteBuffers call, successful shader stages have no observed glDeleteShader/glDetachShader call, and normal HGLRC deletion remains unresolved beyond the static call graph.
- [x] Map all 13 stock shader IDs to their vertex/fragment pairs and connect MDL UV/color/tangent/skin/projection channels through VDO masks to GL attribute slots/formats.
- [x] Correlate renderer states `0x10`, `0x20`, `0x40000` and VDO mask `0x18` with texture-coordinate, lighting, environment-map, and normal-map shader macros.
- [x] Map custom material parameter record fields, float-array/integer type codes, per-variant uniform locations, and `oParam` setter syntax.
- [ ] Identify semantic meanings of individual material uniforms and complete the remaining extension inventory.

Evidence so far: [Initial OpenGL render-path findings](evidence/rendering-pipeline.md).

## Milestone 2: First object rendered

**Status: First static rock visibly rendered**

- [x] Extract ASCII and binary MDL samples plus referenced TGA textures into the OS temp directory only.
- [x] Render static ASCII and binary triangle-list trimeshes, hierarchy, and bitmap maps in the Three.js viewer.
- [x] Validate a second ASCII prop model and geometry-block boundaries.
- [x] Verify the desktop Electron shell loads the styled production bundle.
- [x] User screenshot confirms the volumetric rock is visible in the model viewport.
- [x] Add a bounded binary MDL path for static triangle-list meshes.
- [x] Decode the full 0xC0 skin extension, four-weight/four-index streams, inverse-bind arrays, and 64-slot constant map across multiple assets.
- [x] Apply parsed skin weights through mapped static hierarchy matrices.
- [x] Add a shared binary/ASCII transform/opacity runtime, supermodel clips, mapped skin updates, attachment playback, and authored door transitions; validate representative installed assets and renderer controls.
- [ ] Complete controller/animated-mesh/dangly coverage, unmapped skin variants, blending/event dispatch, gameplay animation selection, and triangle strips.

Evidence: [First object-render milestone](evidence/first-object-render.md).

Nine reviewed Ghidra names across the WGL loader, bootstrap context, SDL window/HDC, pixel-format, and context activation path are backed up locally at `backups/milestone-20261010-window-context-labels-saved/`. The copied project was reopened read-only and all names were verified with `scripts/VerifyRendererLabels.java`; the pre-edit recovery point is `backups/milestone-20261010-scene-context-pre/`.

## Later subsystem tracks

- See [Replacement Client Roadmap](REPLACEMENT_CLIENT_ROADMAP.md) for ordered milestones and completion gates.
- Local movement/door checkpoint: [target DWK state evidence, collision changes, and Witch's Wake validation](evidence/local-movement-doors.md). Nearby visible doors now open/close locally; a representative scripted door round trip now passes; broader traversal and script APIs remain open.
- General animation foundation: [controller evidence, shared runtime, real asset checks, and remaining gaps](evidence/model-animation.md).
- Gameplay priority: [native door click/action evidence and shared object/action foundation](evidence/door-click-gameplay.md). Pointer picking, approach planning, cancellation, arrival-time rule checks and state-driven transitions are implemented. The first script/object/traversal slice now passes; full startup engine APIs are the next blockers.
- World radial checkpoint: [native menu entry, lifecycle, slots, callbacks and implementation limits](evidence/radial-menu.md). Shared modal and nested menus, native icons, object-family providers, placeholder logs and explicit linked-door closing are implemented. Character rules, inventory/merchant, DM/quickbar workflows and most action systems remain open.
- [ ] Resource formats and asset-loading lifecycle (models, textures, materials, areas).
- [ ] Client networking and world replication; reconcile with existing protocol research in `../FullDecomp`.
- Script/object execution checkpoint: [native registry, typed VM and deferred events, real transition scripts and remaining accuracy gaps](evidence/script-object-runtime.md). Persistent uint32 IDs are shared by scripts, actions and render bindings; all authored area objects and owned items are indexed.
- [ ] Complete script VM and gameplay-facing engine calls.
- [ ] World/object model, simulation, and serialization.
- [ ] Runtime validation matrix and compatibility notes.

## Completion standard

A subsystem is not “decompiled” merely because Ghidra produced pseudocode. Mark it mapped only when the major entry points, data structures, callers/callees, state transitions, and error/cleanup paths are documented, with representative behavior validated. Keep unknowns visible; do not infer complete coverage from a function count.
