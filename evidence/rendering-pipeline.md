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

The normal context path is mapped at the control-flow level. `FUN_140b2e470` installs the WGL callback table, including `LoadOpenGLLibraryAndWGLFunctions` and `SwapWindowBuffers`, then enters `CreateSDLWindowWGLContext` (`0x140af2c10`). That routine creates a context for the actual window HDC, using legacy `wglCreateContext` when the requested configuration permits or resolving `wglCreateContextAttribsARB` for the requested GL version/profile. It then calls `MakeSDLWindowWGLContextCurrent` (`0x140af3510`), which activates the HDC/HGLRC pair via the loaded `wglMakeCurrent` pointer and reports failure. The normal SDL window path runs through `CreateSDLWin32Window` (`0x140aefcb0`), `InitializeSDLWin32WindowData` (`0x140aef960`), and `SetSDLWindowPixelFormat` (`0x140af37f0`). Normal window destruction and renderer teardown are still **Open**.

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

### Shader selection, source loading, and uniforms

- `GLRender::RenderVertexData` (`0x1400b59b0`) selects a `ShaderType_t` from `VertexDataObject` flags at `+0x38` and `+0x2c`, renderer-state bits, and `usenew`; it calls `SetProgram` at `0x1400b5ac0`. `RenderVertexStreamData` (`0x1400b5c20`) calls the same selector at `0x1400b5d36`. The exact semantic names for the tested mask/state bits remain **Open**; the evidence establishes their branching role, not their labels.
- `GLRender::SetProgram` (`0x1400b7a40`) uses the current custom program for shader type `0xE` when it has a linked program; otherwise it falls back to stock type `0xC`. Stock programs are indexed as two variants per type, with the selected variant controlled by renderer state and dissolve state. `SetUniforms` (`0x1400b8380`) is called at `0x1400b7a85` and `0x1400b7aff` after program selection.
- `GLRender::ReloadShaders` (`0x1400b5110`) rebuilds loaded custom programs and 13 stock shader types, each with two variants. It is reached through the wrapper at `0x1400bee80`; `Scene::Render` calls that wrapper at `0x1400cc9bd` only when `RenderInterface::bShaderReloadPending` is set, then clears the pending flag. The stock table contains source identifiers including `vslitnotex`, `fslit`, `vslitnt_sm`, `fslit_sm`, `vslit_nm`, `fslit_nm`, `vslit_sm_nm`, `fslit_sm_nm`, `vsvt_sm`, `fst_sm`, `vsvtc`, `vsglu`, and `fsglu`. Exact source-pair-to-enum mapping remains **Open**.
- `FUN_1400b46d0` loads a shader identifier as an Aurora `.shd` resource and recursively expands a leading `#include`. `GLRender::LoadAndCompileSingleShader` (`0x1400b42d0`) prepends `#version 330 core` and build/feature macros, including maximum lights, 64 bones, gamma correction, fragment lighting, quality mode, keyholing, debug mode, and post-processing types. `GLRender::LoadShader` (`0x1400b45b0`) compiles vertex (`0x8b31`) and fragment (`0x8b30`) stages, substitutes `vs_invalid`/`fs_invalid` on failure, optionally compiles a geometry stage (`0x8dd9`), attaches stages, and connects shader data.
- `GLRender::ConnectShaderData` (`0x1400add20`), called from `LoadShader` at `0x1400b46a7`, binds vertex attributes by name, checks link status, and resolves standard uniform locations. Observed attributes include `vTcIn`, `vColor`, `vCustomColor`, `vNormal`, `vIndex`, `vWeight`, `vTangent`, `fHandedness`, `vStaticLightDir`, and additional texture-coordinate sets. Observed uniforms include `m_mvp`, `m_normal`, `m_view`, `m_proj`, `m_view_inv`, `m_proj_inv`, `m_vp_inv`, `skinmesh`, `m_bones[0..63]`, per-light ambient/diffuse/position/attenuation/color, module time, area weather/wind, fog/material values, and texture-unit/bound-state pairs.
- `Material::CheckAndBindCustomShader` (`0x140082b80`) is called from `PartTriMesh::Mat` (`0x1400a3189`), `PartTriMesh::MatStatic` (`0x1400a32c4`), and `RenderEmitter` (`0x1400640f3`). The two mesh material paths bind standard textures first, then choose one of two custom-program slots according to blend/dissolve state and pass the material's parameter list. Parameter type `0` supplies a float array and component count; type `1` supplies an integer. The parameter records carry separate uniform-location fields for the two variants.
- `GLRender::SetCustomParameterValuef` (`0x1400b6df0`) and `SetCustomParameterValuei` (`0x1400b6f00`) update cached values and invalidate the custom program's uniform cache only when values change. `SetUniforms` then flushes changed values to linked-program locations. No distinct vector setter was found; float arrays can carry multiple components, but material-level vector semantics remain **Open**.
- `SetUniforms` caches prior values before issuing uploads. Its observed categories include transform matrices, current-scene lighting and fog, light arrays, area ambient/diffuse, bound texture-stage state, global shader constants, and exposed runtime parameters. Scene-dependent values are gated on `currentscene` being non-null; exact stock source-pair and material-parameter names are not fully decoded.

These findings are from Ghidra decompilation and reference/disassembly queries against NWN:EE `89.8193.37-17` in the existing Ghidra 11.3.2 project. No Ghidra database edits were made for this shader pass.

### Skinned mesh draw path

- `PartSkin::Draw` (`0x1400deb40`) checks `PartTriMesh::IsPartRenderable`, performs the part draw setup, retrieves its `VertexPrimitiveSkinned`, and calls `RenderSkinned` at `0x1400deb7c`.
- `RenderSkinned` (`0x1400e0410`) gathers the part hierarchy's bone transforms with `GatherBones` (`0x1400df000`) and calls `ExecuteSkinGPU` at `0x1400e0636`. The inspected `GatherBones` code accumulates positions and quaternions recursively through child parts.
- `ExecuteSkinGPU` (`0x1400deb90`) processes at most 64 bone slots, composes a transform per available bone, and calls `RenderInterface::SetBoneMatrix` at `0x1400dee43`. The renderer implementation (`0x1400b6950`) rejects indices above 63, transposes each matrix, and stores it in the renderer's bone array. Shader reflection resolves `skinmesh` and `m_bones[0..63]`, matching the 64-bone compile limit.
- After enabling render state `0x15`, `ExecuteSkinGPU` selects the normal `RenderFlat` or `RenderEnvironmentMapped` path according to material/environment-map state. The evidence supports vertex-shader skinning through bone uniforms, not a compute-shader pass. State bit `0x15`'s semantic name remains **Open**.
- `RenderSkinned`'s virtual call at `0x1400e044f` is `PartSkin::PostProcess` (`0x1400df860`, PartSkin vtable slot 27 / byte offset `0xd8`). It gathers the inline Part list, resolves each of the four `SkinVertexWeight` bone names to a part index, remaps valid indices to compact GPU slots, writes the 4-component weight/index streams, and fills the 64-entry slot-to-bone map. Zero weights and invalid indices become zero / `-1` entries.
- The stock PC vertex shader path in `data/base_shaders.bif` (`vslit` -> `inc_standard` -> `inc_common`) gates skinning on `skinmesh == 1`. For each positive component of `vWeight`, it adds `m_bones[int(vIndex.component)] * vPos * vWeight.component`; normals and tangents use the corresponding `mat3(m_bones[index])` transform. This connects PartSkin preprocessing -> `vIndex`/`vWeight` -> 64 `m_bones` uniforms -> weighted vertex position -> the existing flat/environment draw and GL submission path.

The viewer now parses the `0xC0` skin extension, per-vertex weight/index streams, bone reference arrays, and slot map, and applies mapped weights through static hierarchy matrices. Animated poses and exceptional/unmapped skin variants remain **Open** in the viewer; the engine-side render tail is mapped.

### Frame presentation

`SwapBuffers` has a computed call from `FUN_140af3a60` at `0x140af3a6f`. Decompilation of `FUN_140af3a60` shows a small wrapper that calls `SwapBuffers` with an HDC reached through its second argument, then calls an error-reporting function if the Win32 call fails. `FUN_140b2e470` installs this wrapper in the Win32 video-driver callback table. The outer scheduler's instruction-level presentation call is mapped (`Update` calls `RenderInterface::SwapBuffers` at `0x1400450a6`); dispatch from that abstraction to the installed Win32 callback remains **Open**.

The function-reference query returns data references from `FUN_140ab9cf0`, `FUN_140b2e470`, and `FUN_140b2e580`; these are candidate callback/dispatch connections, not yet proof of the main frame loop.

### Outer client frame loop and presentation

- `SDL_main` at `0x140046340` initializes SDL, creates the `Neverwinter Nights` window and GL context, then enters `while (g_bExitProgram == 0)`. Its call to `Update(nullptr)` is at `0x140046dc4`. On exit it calls `RenderInterface::Shutdown(1)`, destroys the server and app-manager components, and calls `SDL_Quit` when SDL video remains initialized.
- `Update` at `0x1400448b0` drains `SDL_PollEvent` through `WinMessageHandler`, handles Aurora reinitialization and frame limiting, then calls the client-app manager wrapper `FUN_1406ac470` at `0x140044de5`. That wrapper forwards to `FUN_1406db800` at `0x1406ac474`; the client worker updates world-time snapshots and delta time, updates resources, calls `AurMakeCurrent`, processes network/client state, and calls `CGuiMan::UpdateAndRender` (`0x1401f70e0`).
- `Update` calls the separate `CServerExoApp::MainLoop` wrapper at `0x140044e09`. The wrapper calls `CServerExoAppInternal::MainLoop` at call site `0x14055bcb4` (entry `0x140567380`). The internal loop is server/network/simulation work (`CNetLayer`, `CServerAIMaster`, `UpdateClientGameObjects`, resource/config updates), not the client frame scheduler.
- After those updates, `Update` calls `BeginScene` at `0x140044eb6`, draws posted strings through `AurRenderStrings`, calls `EndScene` at `0x14004509a`, and presents through `SwapBuffers(g_pWindow)` at `0x1400450a6`. The post-present app-manager helper call is at `0x1400450c8`.
- `FUN_1406db800` calls `CGuiMan::UpdateAndRender` at `0x1406dc26a` (also called by `UpdateScreen` at `0x1400452e4`). The manager iterates its `CSceneView` list at `this + 0x18`: `Scene::Animate` is dispatched through each view's first field at `0x1401f7491`, then its camera field at `CSceneView + 8` invokes Camera vtable slot `+0x10` at `0x1401f75df`. That slot is `Camera::RenderScene` (`0x14005a5d0`), which dispatches `Scene::Render` at `0x14005b208`; the scene pass chain is mapped above. This closes the client worker-to-scene-render handoff. Which registered `CSceneView` is the live gameplay view remains **Open**; confirmed GUI callers include character/model preview panels.
- The renderer abstraction's `SwapBuffers` call is connected to the outer frame, but dispatch from that abstraction to the installed Win32/WGL callback remains **Open**.
- The confirmed `NewCAurCamera` (`0x140059f70`) consumers include `CSceneView::CSceneView` (`0x1401f37f0`) and `CGuiPanel::CreateSceneView` (`0x1401fc230`), which create a paired `CAurScene`/`CAurCamera` for GUI scene views. `CGuiPanel::RenderSceneViewFirst` (`0x1401fc940`) and `RenderSceneViewLast` (`0x1401fc9b0`) only reorder the GUI manager's scene-view list. This establishes a GUI camera path, not the live-world camera owner. Another xref to `NewCAurCamera` exists at `0x1407cd3b9`, but Ghidra finds no containing function there, so its owner and role are **Open**.

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
The preceding client-frame callsite trace supersedes the older sentence above that left the client-worker-to-camera dispatch open. The remaining frame questions are which registered `CSceneView` is the live gameplay viewport, how renderer `SwapBuffers` reaches the installed WGL callback, and normal window/context teardown.


- NWN:EE's Windows renderer uses WGL/OpenGL rather than Direct3D for this target build.
- Some functions newer than the statically imported OpenGL entry points may be resolved dynamically through `wglGetProcAddress`.
- `RenderVertexStreamData` sits below multiple specialized rendering paths; finding its callers' callers should lead toward world-scene orchestration.

## Next probes

1. Map normal window/context destruction and GL resource teardown.
2. Trace the renderer abstraction's `SwapBuffers` dispatch to the installed Win32/WGL callback.
3. Identify which registered `CSceneView` is the live gameplay viewport and trace its activation/lifecycle.
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
| `0x140aefcb0` | `CreateSDLWin32Window` | Creates the sized application HWND and optional parent window |
| `0x140aef960` | `InitializeSDLWin32WindowData` | Acquires/stores the HWND's HDC and initializes SDL window state |
| `0x140af37f0` | `SetSDLWindowPixelFormat` | Chooses/applies the primary window pixel format |
| `0x140af3790` | `InitializeSDLWindowOpenGLContext` | Combines pixel format setup with WGL context creation/activation |
| `0x140af2c10` | `CreateSDLWindowWGLContext` | Selects legacy or attribs-based context creation |
| `0x140af3510` | `MakeSDLWindowWGLContextCurrent` | Calls the loaded `wglMakeCurrent` and checks its result |

The saved milestone copy at `backups/milestone-20261010-window-context-labels-saved/` was reopened read-only with analysis disabled. `scripts/VerifyRendererLabels.java` confirmed all nine names at their expected addresses. `backups/milestone-20261010-scene-context-pre/` is the preceding recovery point; `backups/milestone-20261010-wgl-labels-saved/` remains the earlier WGL baseline.

## Follow-up Corrections
The later client-frame trace supersedes the earlier statement that the client-worker-to-camera handoff is open: `FUN_1406db800` calls `CGuiMan::UpdateAndRender` at `0x1406dc26a`; its `CSceneView` loop calls `Scene::Animate` at `0x1401f7491` and the camera's `RenderScene` vtable slot at `0x1401f75df`. That reaches `Camera::RenderScene` -> `Scene::Render` -> `RenderSinglePass`. The registered view's identity as the live gameplay viewport remains **Open**.


These findings supersede the earlier open-status statements in this note. The normal WGL context path is mapped: `FUN_140b2e470` installs the Win32 OpenGL callback table and enters `FUN_140af2c10`; that function creates a context through legacy `wglCreateContext` or `wglCreateContextAttribsARB`, then `FUN_140af3510` activates it with `wglMakeCurrent`. Window creation/destruction and context teardown remain open.

The Scene vtable address point is `0x140d8dd30`, installed by `Scene::Scene` at `0x1400c0ca0`. `Camera::RenderScene` dispatches `Scene::Render` at call site `0x14005b208` through slot `+0x18`. After bucket population, `Scene::Render` dispatches `Scene::RenderSinglePass` at call site `0x1400ccdc9` through slot `+0x210`; that pass consumes world draw buckets before final presentation. The outer scheduler and client-worker-to-scene dispatch are now mapped. Remaining open work is identifying the live gameplay `CSceneView`, tracing the SwapBuffers-to-WGL callback, and mapping window/context teardown.