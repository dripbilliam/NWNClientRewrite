# Research Tracker

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
- [x] Trace normal WGL context creation and activation.
- [x] Trace Camera::RenderScene through Scene::Render into RenderSinglePass.
- [x] Record the ordered scene bucket/render passes.
- [x] Map the SDL_main application loop, per-frame Update ordering, overlay pass, and renderer shutdown call.
- [ ] Connect the client frame worker to Camera::RenderScene and trace the presentation callback to WGL.
- [ ] Map normal window/context teardown.
- [ ] Decode shader ID/feature-bit semantics, exact stock source pairings, material-level parameter names/types, and the remaining extension inventory.

Evidence so far: [Initial OpenGL render-path findings](evidence/rendering-pipeline.md).

## Milestone 2: First object rendered

**Status: First static rock visibly rendered**

- [x] Extract ASCII and binary MDL samples plus referenced TGA textures into the OS temp directory only.
- [x] Render static ASCII and binary triangle-list trimeshes, hierarchy, and bitmap maps in the Three.js viewer.
- [x] Validate a second ASCII prop model and geometry-block boundaries.
- [x] Verify the desktop Electron shell loads the styled production bundle.
- [x] User screenshot confirms the volumetric rock is visible in the model viewport.
- [x] Add a bounded binary MDL path for static triangle-list meshes.
- [ ] Extend binary parsing to triangle strips, skinned/dangly meshes, and animated/model-state paths.

Evidence: [First object-render milestone](evidence/first-object-render.md).

Nine reviewed Ghidra names across the WGL loader, bootstrap context, SDL window/HDC, pixel-format, and context activation path are backed up locally at `backups/milestone-20261010-window-context-labels-saved/`. The copied project was reopened read-only and all names were verified with `scripts/VerifyRendererLabels.java`; the pre-edit recovery point is `backups/milestone-20261010-scene-context-pre/`.

## Later subsystem tracks

- [ ] Resource formats and asset-loading lifecycle (models, textures, materials, areas).
- [ ] Client networking and world replication; reconcile with existing protocol research in `../FullDecomp`.
- [ ] Script VM and gameplay-facing engine calls.
- [ ] World/object model, simulation, and serialization.
- [ ] Runtime validation matrix and compatibility notes.

## Completion standard

A subsystem is not “decompiled” merely because Ghidra produced pseudocode. Mark it mapped only when the major entry points, data structures, callers/callees, state transitions, and error/cleanup paths are documented, with representative behavior validated. Keep unknowns visible; do not infer complete coverage from a function count.