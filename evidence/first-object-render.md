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

The new Electron/Three.js desktop viewer parses static ASCII MDL `node trimesh` sections inside the base `beginmodelgeom` block, builds the parent hierarchy, converts Z-up model coordinates to the viewer's Y-up convention, expands triangle faces with per-corner UV indices, and binds supplied TGA files by bitmap resref. Parsing only the base geometry block is important: later animation sections repeat node names with no static vertex arrays and must not replace the model's geometry groups.

The first sample was `dag_chest.mdl`, selected from `data/os_models.bif`. Its referenced maps were `plc_creats.tga`, `plc_flag07.tga`, and `plc_rck.tga` from `data/textures_02.bif`. A focused KEY/BIF extractor wrote only these selected resources to the OS temp directory. A second sample, `dag_obelisk.mdl`, was used to catch and fix duplicate animation-node handling.

Browser validation reported:

- Status: `MODEL RENDERED`
- 15 nodes, 6 meshes, 70 vertices, 78 faces
- All three TGA bitmaps resolved
- Desktop browser viewport displayed the textured mesh without shader errors after constructing Three.js `DataTexture` objects from TGALoader's parsed image data
- `dag_obelisk`: 12 base-geometry nodes, 3 meshes, 45 vertices, 76 faces; renders without textures using a bitmap-derived material color
- No browser console warnings/errors after filtering `bitmap NULL` and constructing valid DataTexture UV matrices

The Electron shell was launched as a separate native window with a styled 1440x960 layout after configuring Vite's production base as relative (`./`). The native window styling was verified from a direct `PrintWindow` capture; its startup position is explicitly on the primary desktop. The user confirmed the native file picker opened, but the first selected file was a binary MDL and was correctly rejected by the current ASCII-only parser. Native-window mesh rendering still needs the extracted ASCII chest sample selected.

The selective extractor `scripts/extract_key_bif_resource.py` parses KEY resource names/type IDs and BIF resource offsets, then writes only the requested payload. `npm audit --omit=dev` reports zero runtime dependency vulnerabilities; the full development dependency tree currently reports six advisories.

## Limits and next work

This proves the first static ASCII model can be rendered independently; it does not prove full NWNee visual equivalence. Missing parts include binary MDL, skinning/animation, emitters/effects, lighting/material semantics beyond supplied TGA maps, dynamic scene state, and EE-only resource variations. Continue validating model parsing against more assets and map the Ghidra texture/shader path before making stronger compatibility claims.