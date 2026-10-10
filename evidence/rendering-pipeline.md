# Initial OpenGL Render-Path Findings

**Research date:** 2026-10-10  
**Target:** NWN:EE `89.8193.37-17`, x64 PE  
**Analysis source:** Existing Ghidra 11.3.2 project `../FullDecomp/ghidra-projects/NWN-EE-8193.37-17.gpr`, through its local GhidraMCP endpoint.  
**Scope:** Read-only inspection. No binary or Ghidra database changes.

## Observed

### Graphics API imports

Ghidra's import table contains 43 matching OpenGL/WGL and pixel-format procedures. Representative entries:

| Import | Ghidra external address | Significance |
|---|---:|---|
| `wglGetProcAddress` | `EXTERNAL:00000001` | Runtime lookup of OpenGL procedures |
| `glViewport` | `EXTERNAL:00000003` | Viewport state |
| `glTexImage2D` | `EXTERNAL:00000008` | Texture upload |
| `glDrawElements` | `EXTERNAL:00000017` | Indexed draw submission |
| `glDrawArrays` | `EXTERNAL:00000018` | Non-indexed draw submission |
| `glBindTexture` | `EXTERNAL:00000025` | Texture binding |
| `ChoosePixelFormat` | `EXTERNAL:000001a3` | Win32 pixel-format selection |
| `SetPixelFormat` | `EXTERNAL:000001a6` | Win32 pixel-format application |
| `SwapBuffers` | `EXTERNAL:000001a7` | Win32/OpenGL buffer presentation |

This establishes a native Win32/OpenGL render path. Dynamic GL extension loading is confirmed below through `wglGetProcAddress` lookups and their loader routines.

### WGL library and bootstrap context

The strings `wglCreateContext` (`0x140e95548`) and `wglMakeCurrent` (`0x140e95578`) both reference `FUN_140af3390` (`0x140af3390`). Its decompilation reads `SDL_OPENGL_LIBRARY` and defaults to `OPENGL32.DLL`, loads that library, and resolves `wglGetProcAddress`, `wglCreateContext`, `wglDeleteContext`, `wglMakeCurrent`, and `wglShareLists`. It then calls `FUN_140af3000`.

`FUN_140af3000` creates a hidden 10x10 Win32 window, obtains its device context, chooses and applies a pixel format, creates and activates a temporary legacy WGL context, and queries `wglGetExtensionsStringARB`. It conditionally resolves WGL extensions including `WGL_ARB_pixel_format` and `WGL_EXT_swap_control`, checks additional context flags, then clears and deletes the temporary context and destroys the window. This is the bootstrap/extension-discovery path.

The normal context path is mapped at the control-flow level. `FUN_140b2e470` installs the WGL callback table, including `LoadOpenGLLibraryAndWGLFunctions` and `SwapWindowBuffers`, then enters `FUN_140af2c10`. That routine creates a context for the actual window HDC, using legacy `wglCreateContext` when the requested configuration permits or resolving `wglCreateContextAttribsARB` for the requested GL version/profile. It then calls `FUN_140af3510`, which activates the HDC/HGLRC pair via the loaded `wglMakeCurrent` pointer and reports failure. Normal window creation/destruction and renderer teardown are still **Open**.

### Geometry submission

`GLRender::RenderVertexStreamData` begins at `0x1400b5c20`; an imported `glDrawElements` computed call is at `0x1400b5d59`.

The decompilation shows this routine:

1. Applies a `VertexStreamDataObject` through `SetVertexStreamDataObject`.
2. Selects a shader/program based on object flags, renderer state, and whether a custom program is active.
3. Uses `glDrawArrays` when the object's field at offset `+8` is zero.
4. Otherwise uses `glDrawElements` with `GL_UNSIGNED_SHORT` (`0x1403`) and an index offset derived from the fourth argument.
5. Clears selected renderer state after submission.

The function has callers including `DrawLines`, `RenderBox`, `DrawFromVerts`, `DrawBoundingBox`, and `RenderDrawableSquares`. It is a low-level geometry helper used by multiple rendering/UI/effect paths; this alone does not identify the main world-scene traversal.

### World objects, parts, and mesh buckets

- `Gob::Render` at `0x1400a4280` applies a Gob's position/orientation and accumulated scale, then calls `Gob::PartDraw` (`0x1400a3440`) on its root part.
- `Gob::PartDraw` applies each part's local transform, calls a virtual method at vtable offset `0xc8` (byte offset 200), and recursively visits child parts. RTTI/vtable analysis resolves the `PartTriMesh` override to `PartTriMesh::Draw` at `0x1400a24c0`.
- `Scene::AddPartsTreeToDrawBuckets` at `0x1400c4620` recursively transforms a part tree. For mesh parts it checks `PartTriMesh::IsPartRenderable`, copies the current model matrix into mesh-associated state, classifies the part by material/opacity/effect state, and queues it with `DrawBucketManager::AddPartToBucket`.
- `Scene::AddPartsToDrawBuckets` at `0x1400c38f0` resets the bucket manager and walks the global mesh, fade, cap, and static-shadow collections. It filters non-renderable meshes and assigns material/effect-specific buckets.
- `Scene::RenderDrawBucket` at `0x1400cd210` consumes bucket items, obtains associated `PartTriMesh` and `MdlNodeTriMesh` data, sets model and shader parameters, applies fog/dissolve state, then dispatches a virtual draw operation. Debug bounds/pivots are handled separately.
- `Scene::Render` at `0x1400cc730` performs scene-level setup and calls `AddPartsToDrawBuckets`; its post-collection virtual dispatch and pass order are detailed below.

This establishes object transforms -> part tree -> `PartTriMesh` collection -> material/effect draw buckets -> virtual mesh draw -> renderer vertex submission as the static data path. The virtual target and the loaded vertex/index-buffer lifecycle remain to be mapped before implementing equivalent object rendering.

### Concrete mesh-to-GPU path

The RTTI scan in `scripts/InspectPartTriMeshVtable.java` found the x64 `PartTriMesh` complete-object locator at `0x140ee6940`, vtable at `0x140d88308`, and inherited `Part::Draw` slot 25 at `0x140d883d0`. That slot points to `PartTriMesh::Draw` at `0x1400a24c0`.

The simple flat-material path is now traced:

1. `PartTriMesh::Draw` (`0x1400a24c0`) selects the flat, environment-mapped, or bumpy/shiny path.
2. `RenderFlat` (`0x1400a4710`) selects a render hint and passes its `VertexDataObject` item to the render interface.
3. `GLRender::RenderVertexData` (`0x1400b59b0`) binds the `VertexDataObject`, chooses a shader program from vertex/state flags, and dispatches `glDrawElements` using 16-bit indices or `glDrawArrays` for the non-indexed mode.
4. `GLRender::SetVertexDataObject` (`0x1400ba770`) binds element/array buffer objects and configures enabled vertex attributes through the dynamically loaded `glVertexAttribPointer`.
5. `VertexPrimitiveFlat::SetupArrays` (`0x1400abca0`) combines mesh channels and face UV indices into static/dynamic `VertexDataObject` pools. `MdlNodeTriMesh::GenerateVertexData` (`0x1400a7790`) creates per-mesh source pools for position, UV, and optional normal/tangent/color channels.
6. `GLRender::UnlockPool` (`0x1400bbad0`) uploads or updates pool storage with dynamically loaded `glGenBuffers`, `glBufferData`, and `glBufferSubData`.

`FUN_140b7a0f0` is the WGL loader for buffer/query entry points; `FUN_140b7a350` loads shader, uniform, and vertex-attribute entry points. These names remain evidence-derived notes rather than Ghidra symbols for now. Together with the earlier scene-bucket findings, this identifies both the object path and the data required to issue a mesh draw.

### Frame presentation

`SwapBuffers` has a computed call from `FUN_140af3a60` at `0x140af3a6f`. Decompilation of `FUN_140af3a60` shows a small wrapper that calls `SwapBuffers` with an HDC reached through its second argument, then calls an error-reporting function if the Win32 call fails. `FUN_140b2e470` installs this wrapper in the Win32 video-driver callback table. The outer application frame scheduler and exact invocation point of the presentation callback remain **Open**.

The function-reference query returns data references from `FUN_140ab9cf0`, `FUN_140b2e470`, and `FUN_140b2e580`; these are candidate callback/dispatch connections, not yet proof of the main frame loop.

### Scene bucket categories

Observed in `Scene::AddPartsToDrawBuckets` (`0x1400c38f0`) and `Scene::AddPartsTreeToDrawBuckets` (`0x1400c4620`):

| Bucket ID | Direct classification evidence |
|---:|---|
| 0 / 1 | Global mesh path separates the ordinary opaque/default case from its alternate opacity case |
| 2 / 3 | Recursive part-tree path separates opaque from non-opaque parts |
| 4 / 5 / 6 | Material/effect-specific branches; bucket 6 includes bumpy-shiny or a related material effect path |
| 7 | Cap-mesh collection |
| 8 | Fade-mesh collection |
| 9 / 10 | Static-shadow collection; selected according to the shadow flip-order state |

These are bucket insertion rules, not a complete description of each material shader. Keep labels such as “opaque” for 0/1 and 2/3 as **inferred** from `GetIsOpaque` branches until every `DrawBucketManager` consumer is reviewed.

### Camera-to-scene frame dispatch and pass order

- The `Scene` constructor at `0x1400c0ca0` installs the vtable address point `0x140d8dd30`.
- `Camera::RenderScene` at `0x14005a5d0` dispatches through the attached scene pointer at call site `0x14005b208`, vtable byte offset `+0x18`. The target is the `Scene::Render` entry at `0x140d8dd48` (`0x140d8dd30 + 0x18`), function `0x1400cc730`.
- `Scene::Render` manages scene BSP/lighting and calls `AddPartsToDrawBuckets` at `0x1400c38f0`; its indirect call at `0x1400ccdc9` uses vtable byte offset `+0x210`.
- The `Scene` vtable entry at `0x140d8df40` (`0x140d8dd30 + 0x210`) targets `Scene::RenderSinglePass` at `0x1400d0f10`.
- `RenderSinglePass` initializes the main-scene framebuffer, obtains shadow lights when enabled, calls pre/post scene hooks, and consumes draw buckets in the observed order: `0`, skyboxes, `1`, `7`, dynamic-shadow/projection work, `5`, fade bucket `8`, static-shadow work, `6`, optional wireframe repeats (`0`, `1`, `7`, `8`, `2`, `3`, `5`, `6`), then bucket `4`, framebuffer effects, drawable squares, and optional light-range diagnostics.
- Individual mesh buckets are consumed by `Scene::RenderDrawBucket` at `0x1400cd210`; this is the route that reaches the already-mapped `PartTriMesh::Draw` and `GLRender::RenderVertexData` path.

This establishes a per-scene camera -> Scene::Render -> collect parts -> RenderSinglePass -> draw-bucket -> PartTriMesh::Draw chain. The outer application frame scheduler and normal window/context creation and teardown remain **Open**. Bucket numeric meanings should remain provisional until each `DrawBucketManager` classification and consumer are cross-checked.

## Inferences (not yet confirmed)

- NWN:EE's Windows renderer uses WGL/OpenGL rather than Direct3D for this target build.
- Some functions newer than the statically imported OpenGL entry points may be resolved dynamically through `wglGetProcAddress`.
- `RenderVertexStreamData` sits below multiple specialized rendering paths; finding its callers' callers should lead toward world-scene orchestration.

## Next probes

1. Trace the normal application-window/context creation path and distinguish it from the mapped hidden bootstrap context.
2. Trace callers of `FUN_140af3a60` to identify frame presentation and the main loop boundary.
3. Trace which scene passes consume each material/shadow bucket and connect `Camera::RenderScene` to the main world frame loop.
4. Map shader source selection, uniform setup, texture upload/sampler semantics, and the remaining environment/shadow rendering branches.
5. Reconcile ASCII and binary MDL variants, animation/skinning, and dynamic object state with the viewer's bounded static implementation.

## Reproduction

The existing helper is `../FullDecomp/tooling/NWN-Ghidra.ps1`. `Status` confirmed the Ghidra process and MCP endpoint were online during this inspection. Relevant HTTP bridge reads were `/imports`, `/xrefs_to`, `/function_xrefs`, and `/decompile`; no mutating endpoint was used.

After the read-only baseline snapshot was verified, three high-confidence Ghidra labels were applied and read back:

| Address | Label | Basis |
|---|---|---|
| `0x140af3390` | `LoadOpenGLLibraryAndWGLFunctions` | Loads `SDL_OPENGL_LIBRARY` or `OPENGL32.DLL`; resolves core WGL procedures |
| `0x140af3000` | `InitializeWGLBootstrapContext` | Creates a hidden bootstrap window/context and probes WGL extensions |
| `0x140af3a60` | `SwapWindowBuffers` | Direct wrapper around `SwapBuffers` with failure handling |

The saved milestone copy at `backups/milestone-20261010-wgl-labels-saved/` was reopened read-only with analysis disabled. `scripts/VerifyRendererLabels.java` confirmed all three names at their expected addresses. The earlier snapshot was retained as the pre-edit baseline.

## Follow-up Corrections

These findings supersede the earlier open-status statements in this note. The normal WGL context path is mapped: `FUN_140b2e470` installs the Win32 OpenGL callback table and enters `FUN_140af2c10`; that function creates a context through legacy `wglCreateContext` or `wglCreateContextAttribsARB`, then `FUN_140af3510` activates it with `wglMakeCurrent`. Window creation/destruction and context teardown remain open.

The Scene vtable address point is `0x140d8dd30`, installed by `Scene::Scene` at `0x1400c0ca0`. `Camera::RenderScene` dispatches `Scene::Render` at call site `0x14005b208` through slot `+0x18`. After bucket population, `Scene::Render` dispatches `Scene::RenderSinglePass` at call site `0x1400ccdc9` through slot `+0x210`; that pass consumes world draw buckets before final presentation. The outer application frame scheduler and exact SwapBuffers callback invocation remain open.