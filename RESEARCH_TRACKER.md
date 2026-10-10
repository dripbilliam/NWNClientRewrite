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
- [ ] Trace the normal render-context creation path (bootstrap context is mapped; normal path remains open).
- [ ] Trace callers above low-level geometry submission to scene/world draw orchestration.
- [ ] Map renderer initialization, frame loop, and shutdown paths.
- [ ] Inventory dynamically loaded GL extensions and shader/program setup.

Evidence so far: [Initial OpenGL render-path findings](evidence/rendering-pipeline.md).

## Milestone 2: First object rendered

**Status: Browser proof complete; native desktop asset selection pending**

- [x] Extract ASCII and binary MDL samples plus referenced TGA textures into the OS temp directory only.
- [x] Render static ASCII and binary triangle-list trimeshes, hierarchy, and bitmap maps in the Three.js viewer.
- [x] Validate a second ASCII prop model and geometry-block boundaries.
- [x] Verify the desktop Electron shell loads the styled production bundle.
- [ ] Load `dag_rockledge1.mdl` and its two maps in Electron and verify the textured desktop render.
- [x] Add a bounded binary MDL path for static triangle-list meshes.
- [ ] Extend binary parsing to triangle strips, skinned/dangly meshes, and animated/model-state paths.

Evidence: [First object-render milestone](evidence/first-object-render.md).

Ghidra names applied to the WGL loader, bootstrap-context initializer, and buffer-swap wrapper are backed up locally at `backups/milestone-20261010-wgl-labels-saved/`. The copied project was reopened read-only and the names were verified with `scripts/VerifyRendererLabels.java`.

## Later subsystem tracks

- [ ] Resource formats and asset-loading lifecycle (models, textures, materials, areas).
- [ ] Client networking and world replication; reconcile with existing protocol research in `../FullDecomp`.
- [ ] Script VM and gameplay-facing engine calls.
- [ ] World/object model, simulation, and serialization.
- [ ] Runtime validation matrix and compatibility notes.

## Completion standard

A subsystem is not “decompiled” merely because Ghidra produced pseudocode. Mark it mapped only when the major entry points, data structures, callers/callees, state transitions, and error/cleanup paths are documented, with representative behavior validated. Keep unknowns visible; do not infer complete coverage from a function count.