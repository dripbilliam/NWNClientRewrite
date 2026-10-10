# NWN ASCII Model Viewer Milestone

**Date:** 2026-10-10  
**Target:** NWN:EE `89.8193.37-17`, x64  
**Ghidra source:** `../FullDecomp/ghidra-projects/NWN-EE-8193.37-17.gpr`  
**Asset source:** Existing installation under `../FullDecomp/NwnRootInstall`; extracted outputs remained under `%TEMP%\nwn-model-test-assets` and were not committed.

## Binary render path observed

The NWNee static path from object to OpenGL submission is now traced through Ghidra:

1. `Gob::Render` at `0x1400a4280` applies the Gob transform and calls `Gob::PartDraw` (`0x1400a3440`).
2. `Gob::PartDraw` transforms the part hierarchy and invokes the part's virtual draw slot.
3. MSVC x64 RTTI identifies `PartTriMesh::Draw` at `0x1400a24c0` in the `PartTriMesh` vtable (`0x140d88308`, slot 25 / byte offset `0xc8`).
4. `PartTriMesh::Draw` chooses the flat, environment-mapped, or bumpy/shiny route. The first viewer milestone follows `RenderFlat` at `0x1400a4710`.
5. `RenderFlat` calls `GLRender::RenderVertexData` at `0x1400b59b0`, which selects a shader program and issues indexed draws with 16-bit indices or `glDrawArrays`.
6. `GLRender::SetVertexDataObject` at `0x1400ba770` binds element/array buffers and sets vertex attribute pointers.
7. `VertexPrimitiveFlat::SetupArrays` at `0x1400abca0` and `MdlNodeTriMesh::GenerateVertexData` at `0x1400a7790` populate position, UV, normal, tangent, color, and optional streams from model node data.
8. `GLRender::UnlockPool` at `0x1400bbad0` creates/uploads GPU buffer storage through dynamically resolved `glGenBuffers`, `glBufferData`, and `glBufferSubData`.

Dynamic procedure loaders observed: `FUN_140b7a0f0` resolves buffer-object procedures; `FUN_140b7a350` resolves shader, uniform, and vertex-attribute procedures. These names have not yet been added to Ghidra; the evidence is from their decompilation.

## Viewer implementation and validation

The new Electron/Three.js desktop viewer parses static ASCII MDL `node trimesh` sections inside the base `beginmodelgeom` block and static binary MDL triangle-list meshes. It builds the parent hierarchy, applies static node transforms, converts Z-up model coordinates to the viewer's Y-up convention, reads 16-bit face indices and per-vertex UVs, and binds supplied TGA files by bitmap resref. Parsing only the base ASCII geometry block is important: later animation sections repeat node names with no static vertex arrays and must not replace the model's geometry groups.

The first sample was `dag_chest.mdl`, selected from `data/os_models.bif`. Its referenced maps were `plc_creats.tga`, `plc_flag07.tga`, and `plc_rck.tga` from `data/textures_02.bif`. A focused KEY/BIF extractor wrote only these selected resources to the OS temp directory. A second sample, `dag_obelisk.mdl`, was used to catch and fix duplicate animation-node handling.

For the requested volumetric rock, `dag_rockledge1.mdl` from `data/os_models.bif` has 9 mesh nodes, 1,347 vertices, and 419 faces. Its `TTU01_Rock02` and `TTU01_Moss` bitmaps are `ttu01_rock02.tga` and `ttu01_moss.tga` in `data/xp2_tiles.bif`; both were extracted to temp. `dag_rock1x1.mdl` is only a flat 4-vertex, 2-face tile and is not the boulder-like sample.

Browser validation reported:

- Status: `MODEL RENDERED`
- 15 nodes, 6 meshes, 70 vertices, 78 faces
- All three TGA bitmaps resolved
- Desktop browser viewport displayed the textured mesh without shader errors after constructing Three.js `DataTexture` objects from TGALoader's parsed image data
- `dag_obelisk`: 12 base-geometry nodes, 3 meshes, 45 vertices, 76 faces; renders without textures using a bitmap-derived material color
- `dag_rockledge1`: binary MDL, 10 nodes, 9 meshes, 1,347 vertices, 419 faces; both rock/moss TGA maps resolved
- No browser console warnings/errors after filtering `bitmap NULL` and constructing valid DataTexture UV matrices
- Unsupported binary features produce a viewport-level error rather than a silent no-op

The Electron shell was launched as a separate native window with a styled 1440x960 layout after configuring Vite's production base as relative (`./`). The native window styling was verified from a direct `PrintWindow` capture; its startup position is explicitly on the primary desktop. The current build supports static binary triangle-list meshes. The user confirmed the native file picker opened; native-window verification of the rock remains pending. The browser preview rendered `dag_rockledge1` with both TGA maps, and exact temp paths are documented in `README.md`.

The selective extractor `scripts/extract_key_bif_resource.py` parses KEY resource names/type IDs and BIF resource offsets, then writes only the requested payload. `npm audit --omit=dev` reports zero runtime dependency vulnerabilities; the full development dependency tree currently reports six advisories.

## Limits and next work

This proves representative static ASCII and binary triangle-list models can be rendered independently; it does not prove full NWNee visual equivalence. Missing parts include triangle strips, skinning/animation, dangly meshes, emitters/effects, lighting/material semantics beyond supplied TGA maps, dynamic scene state, and EE-only resource variations. Continue validating binary offsets and transforms against more assets and map the Ghidra texture/shader path before making stronger compatibility claims.