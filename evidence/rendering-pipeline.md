# Initial OpenGL Render-Path Findings

**Research date:** 2026-10-10  
**Target:** NWN:EE `89.8193.37-17`, x64 PE  
**Analysis source:** Existing Ghidra 11.3.2 project `../FullDecomp/ghidra-projects/NWN-EE-8193.37-17.gpr`, through its local GhidraMCP endpoint.  
**Scope:** Read-only inspection. No binary or Ghidra database changes.

## Gameplay Render Tail
The gameplay camera is not selected from the GUI `CSceneView` list. The verified native frame chain is:

`SDL_main -> Update -> FUN_1406db800 -> FUN_140767d50 -> FUN_1407cffc0 -> Camera::RenderScene -> Scene::Render -> RenderSinglePass -> draw buckets -> mesh/skin draw -> GL submission`, followed by GUI rendering and SDL/WGL presentation.

| Edge | Target function | Call site | Validation |
|---|---|---|---|
| Client worker -> gameplay update | `FUN_140767d50` | `0x1406dc249` | Ghidra disassembly + hash-gated binary replay |
| Gameplay update -> module update | `FUN_1407cffc0` | `0x140767fd3` | Ghidra xrefs/decompilation + binary replay |
| Module update -> area update | `FUN_1407e7da0` | Before camera draw in `0x1407cffc0` | Ghidra decompilation |
| Area scene -> animation | `Scene::Animate` (`0x1400c5210`) | `0x1407e9054`, scene `+0x20` | Area scene at `+0x248`, Scene vtable + binary replay |
| Module camera -> scene draw | `Camera::RenderScene` (`0x14005a5d0`) | `0x1407d03ae`, camera `+0x10` | Camera at module `+0xe8`, Camera vtable + binary replay |
| Client worker -> GUI rendering | `CGuiMan::UpdateAndRender` (`0x1401f70e0`) | `0x1406dc26a` | Occurs after gameplay call; binary replay |

`FUN_1407cd2c0` creates `CAurCamera("camera")` at owner `+0xe8` and a `CNWCArea` at `+0xf8`. It is called by the client area-message handler `FUN_1407a4d30`. PE unwind metadata bounds this function at `0x1407cd2c0-0x1407cdd20`; Ghidra incorrectly stops its body at `0x1407cd302` after a call to `FUN_140c10370`. The area update animates its scene before the module draws its camera. GUI preview and overlay cameras are separate consumers of the same native camera/scene renderer.

**Scope of closure:** gameplay dispatch, animation/controller evaluation, mesh/skin submission, and final presentation are statically connected. This does not establish a complete rendering-subsystem decompilation: exact shader feature semantics, exceptional effect branches, complete resource destruction, and target in-game moving-pose comparison remain outstanding. The viewer now implements a [shared animation foundation](model-animation.md); exact skin parity is still open.

`scripts/inspect_render_tail.py` reproduces seven exact instruction checks and the PE camera-initialization range. Run `py -3 scripts/inspect_render_tail.py` with existing `pefile` and `capstone` packages. It refuses binaries with a different SHA-256 and never writes the binary or Ghidra database.

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

The normal context path is mapped at the control-flow level. `FUN_140b2e470` installs the WGL callback table, including `LoadOpenGLLibraryAndWGLFunctions` and `SwapWindowBuffers`, then enters `CreateSDLWindowWGLContext` (`0x140af2c10`). That routine creates a context for the actual window HDC, using legacy `wglCreateContext` when the requested configuration permits or resolving `wglCreateContextAttribsARB` for the requested GL version/profile. It then calls `MakeSDLWindowWGLContextCurrent` (`0x140af3510`), which activates the HDC/HGLRC pair via the loaded `wglMakeCurrent` pointer and reports failure. The normal SDL window path runs through `CreateSDLWin32Window` (`0x140aefcb0`), `InitializeSDLWin32WindowData` (`0x140aef960`), and `SetSDLWindowPixelFormat` (`0x140af37f0`). `CAurInternalGL::ShutDown` (`0x140075750`) and its destructor (`0x140074c70`) destroy the SDL window. The remaining lifecycle question is whether the normal HGLRC is deleted before the process exits.

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

- `GLRender::RenderVertexData` (`0x1400b59b0`) selects a `ShaderType_t` from `VertexDataObject` flags at `+0x38` and `+0x2c`, renderer-state bits, and `usenew`; it calls `SetProgram` at `0x1400b5ac0`. `RenderVertexStreamData` (`0x1400b5c20`) calls the same selector at `0x1400b5d36`. The VDO UV/color/tangent source bits are mapped below; state bit `0x2` controls the `fAlphaDiscardValue` uniform and bit `0x1` controls the `blendMode` uniform. State bits `0x10`, `0x20`, and `0x40000`, plus mask bits `0x4`, `0x1`, and `0x100`, remain **Open** semantically.
- `MdlNodeTriMesh::InternalParseField` (`0x14009e950`) parses `tverts`, `tverts1`, `tverts2`, `tverts3`, `normals`, `colors`, and `tangents` into separate postprocess lists. `MdlNodeTriMeshGenVertices` (`0x140093190`) passes those lists to `NodeVertex::NodeVertex` (`0x1400aaa90`), whose mask at `+0x66` uses source bits `0x1/0x2/0x4/0x8` for `tverts` through `tverts3`, `0x10` for `colors`, and `0x20` for the optional `Vector4` tangent; normals are passed as a regular vector channel without an optional-bit test.
- `MdlNodeTriMesh::GenerateVertexData` (`0x1400a7790`) maps NodeVertex source bits `0x1/0x2/0x4/0x8` to VDO pools at node offsets `+0x288/+0x28c/+0x290/+0x294`; source bit `0x10` allocates `+0x29c`; source bit `0x20` allocates `+0x2ac` and `+0x2b4`. `VertexPrimitiveFlat::SetupArrays` (`0x1400abca0`) maps those pool-presence checks to shader-mask bits `0x800/0x1000/0x2000/0x4000/0x80/0x8/0x10`, respectively. `VertexDataObject::Build` (`0x1400bd0c0`) stores the two masks at VDO offsets `+0x2c` and `+0x38`, and `RenderVertexData` ORs them before selecting a shader. This links the serialized texture-coordinate/color/tangent channels to raw shader selector bits without assigning semantics to the remaining masks.
- `PartSkin::PostProcess` (`0x1400df860`) allocates four-index data at skin offset `+0x2dc` (8 bytes per vertex) and four-float weights at `+0x2d8` (16 bytes per vertex). `SetVertexDataObject` (`0x1400ba770`) binds these as vertex attributes 8 (`vIndex`, four 16-bit components) and 9 (`vWeight`, four floats); consequently shader-mask bit `0x20` denotes indices and bit `0x40` denotes weights.
- Other observed mask producers include bit `0x4` from pool `MdlNodeTriMesh +0x280` with local-state tests; bit `0x2` from `MdlNodeTriMesh +0x298`; bit `0x1` from the owning `PartTriMesh` flag at `+0x9c` together with pool token `+0x98`; and bit `0x100` from its pool token at `+0xb0`. `PartTriMesh::~PartTriMesh` (`0x140089e60`) returns those optional pool IDs through `DeletePool`. Their precise channel/effect meaning and remaining renderer-state bits are still **Open**.
- `GLRender::SetProgram` (`0x1400b7a40`) uses the current custom program for shader type `0xE` when it has a linked program; otherwise it falls back to stock type `0xC`. Stock programs are indexed as two variants per type, with variant index 1 selected when renderer-state bit `0x2` is clear and `m_canDissolve` is false; otherwise it selects variant 0. `SetUniforms` (`0x1400b8380`) is called at `0x1400b7a85` and `0x1400b7aff` after program selection. `ConnectShaderData` maps the corresponding locations to `fAlphaDiscardValue` (`PROG_FIXED +0xac4`) and `blendMode` (`+0x9c`); bit `0x2` selects between alpha-discard constants, while bit `0x1` selects the shader blend-mode value from current blend modes. `Scene::RenderDrawBucket` obtains `Camera::GetCanKeyholeDissolve(CurrentCamera, part)` and passes the result to `RenderInterface::SetCanDissolve` immediately before drawing the part; it resets the state after the bucket. Thus `m_canDissolve` is a per-draw keyhole-dissolve value, not a permanent renderer capability.
- `GLRender::ReloadShaders` (`0x1400b5110`) rebuilds loaded custom programs and 13 stock shader types, each with two variants. It is reached through the wrapper at `0x1400bee80`; `Scene::Render` calls that wrapper at `0x1400cc9bd` only when `RenderInterface::bShaderReloadPending` is set, then clears the pending flag. Its source table maps IDs to vertex/fragment pairs:

| ID | Vertex | Fragment |
|---:|---|---|
| 0 | `vsv` | `fs` |
| 1 | `vsvt` | `fst` |
| 2 | `vsvt_sm` | `fst_sm` |
| 3 | `vsvtc` | `fstc` |
| 4 | `vsvc` | `fsc` |
| 5 | `vslitnotex` | `fslit` |
| 6 | `vslitnt_sm` | `fslit_sm` |
| 7 | `vslit` | `fslit` |
| 8 | `vslit_nm` | `fslit_nm` |
| 9 | `vslit_sm` | `fslit_sm` |
| 10 | `vslit_sm_nm` | `fslit_sm_nm` |
| 11 | `vsglu` | `fsglu` |
| 12 | `vs_invalid` | `fs_invalid` |

The reload table pairings are independently referenced by `GLRender::InitRenderSystem` (`0x1400b3f60`).

The corresponding stock `.shd` resources were read from the target's `data/base_shaders.bif` and extracted only to the OS temp directory. Their macros confirm IDs `0–4` use `LIGHTING=0`, IDs `5–10` use `LIGHTING=1`; each `_sm` pair sets `ENVIRONMENT_MAP=1`; the `_nm` pair sets `NORMAL_MAP=1` (and its fragment shader enables specular, roughness, height, and self-illumination map features); and the no-texture pairs set `NO_TEXTURE_COORDS=1`. Correlating these definitions with the selector branches makes renderer-state bit `0x20` the lighting-family selector, bit `0x10` the texture-coordinate/textured-path gate, and bit `0x40000` the environment-map variant selector. The normal-map branch is chosen only when VDO mask `0x18` (tangent plus handedness) is present and `usenew` is true. These bit-to-feature labels are control-flow inferences corroborated by the stock shader macros; the `_sm` suffix is not expanded beyond the observed environment-map macro.
- `FUN_1400b46d0` loads a shader identifier as an Aurora `.shd` resource and recursively expands a leading `#include`. `GLRender::LoadAndCompileSingleShader` (`0x1400b42d0`) prepends `#version 330 core` and build/feature macros, including maximum lights, 64 bones, gamma correction, fragment lighting, quality mode, keyholing, debug mode, and post-processing types. `GLRender::LoadShader` (`0x1400b45b0`) compiles vertex (`0x8b31`) and fragment (`0x8b30`) stages, substitutes `vs_invalid`/`fs_invalid` on failure, optionally compiles a geometry stage (`0x8dd9`), attaches stages, and connects shader data.
- `GLRender::ConnectShaderData` (`0x1400add20`), called from `LoadShader` at `0x1400b46a7`, binds vertex attributes by name, checks link status, and resolves standard uniform locations. Observed attributes include `vTcIn`, `vColor`, `vCustomColor`, `vNormal`, `vIndex`, `vWeight`, `vTangent`, `fHandedness`, `vStaticLightDir`, and additional texture-coordinate sets. Observed uniforms include `m_mvp`, `m_normal`, `m_view`, `m_proj`, `m_view_inv`, `m_proj_inv`, `m_vp_inv`, `skinmesh`, `m_bones[0..63]`, per-light ambient/diffuse/position/attenuation/color, module time, area weather/wind, fog/material values, and texture-unit/bound-state pairs.

`GLRender::SetVertexDataObject` (`0x1400ba770`) maps the VDO feature mask to the bound attribute layout:

| VDO mask | Shader attribute | Slot | Format |
|---:|---|---:|---|
| `0x1` | `vColor` | 2 | 4 x unsigned byte, normalized |
| `0x2` | `vNormal` | 7 | 3 x float |
| `0x4` | `vPos` | 0 | 3 x float |
| `0x8` | `vTangent` | 4 | 3 x float |
| `0x10` | `fHandedness` | 5 | 1 x float |
| `0x20` | `vIndex` | 8 | 4 x signed short |
| `0x40` | `vWeight` | 9 | 4 x float |
| `0x80` | `vCustomColor` | 3 | 4 x unsigned byte, normalized |
| `0x100` | `vStaticLightDir` | 6 | 3 x float |
| `0x200` | `fProjectionFrontal` | 10 | 1 x float |
| `0x800` | `vTcIn` | 1 | 2 x float |
| `0x1000` | `vTcIn1` | 11 | 2 x float |
| `0x2000` | `vTcIn2` | 12 | 2 x float |
| `0x4000` | `vTcIn3` | 13 | 2 x float |

The projection path independently requests mask `0x204` (`vPos` plus `fProjectionFrontal`) in `SetupProjectionArrays`; skin attributes use the separately verified four-short index and four-float weight pools.
- `Material::CheckAndBindCustomShader` (`0x140082b80`) is called from `PartTriMesh::Mat` (`0x1400a3189`), `PartTriMesh::MatStatic` (`0x1400a32c4`), and `RenderEmitter` (`0x1400640f3`). The two mesh material paths bind standard textures first, then choose one of two custom-program slots according to blend/dissolve state and pass the material's parameter list. Each 100-byte `MaterialParameter` record has its name in the first `0x40` bytes, value storage beginning at `+0x44`, per-variant uniform locations at `+0x54` and `+0x58`, type code at `+0x5c`, and a 16-bit float-value count at `+0x60`. `Material::CheckAndBindCustomShader` dispatches type `0` as a float array plus count and type `1` as a scalar integer; other type values are ignored by this path. `Material::SetMaterialParam` (`0x1400857e0`) recognizes the literal directives `oParam float <name> <value-text>` and `oParam int <name> <value-text>` when updating a named parameter. These facts establish storage and transport types, not the semantic meaning of individual uniform names; vector conventions remain open.
- `GLRender::SetCustomParameterValuef` (`0x1400b6df0`) and `SetCustomParameterValuei` (`0x1400b6f00`) update cached values and invalidate the custom program's uniform cache only when values change. `SetUniforms` then flushes changed values to linked-program locations. The renderer API has no separate vector setter; its float pointer plus count carries arrays. Separately, `CNWSObject::SetMaterialShaderParamI` (`0x14049b3b0`) and `SetMaterialShaderParamVec4` (`0x14049b640`) store script-facing object overrides in a separate array at `CNWSObject +0x2b8` (0x6c-byte records): type code 1 stores an integer, type code 2 stores four floats, keyed by material and parameter names. These object override records are distinct from `MaterialParameter` records consumed by `Material::CheckAndBindCustomShader`; a direct path from the object override array to that renderer list is not established here.
- `SetUniforms` caches prior values before issuing uploads. Its observed categories include transform matrices, current-scene lighting and fog, light arrays, area ambient/diffuse, bound texture-stage state, global shader constants, and exposed runtime parameters. Scene-dependent values are gated on `currentscene` being non-null; exact stock source-pair and material-parameter names are not fully decoded.

### Area, emitter, and shadow lighting path

Evidence from the `89.8193.37-17` target in the existing Ghidra project:

- `CNWSArea::LoadProperties` at `0x140361dd0` reads the ARE `MoonAmbientColor`, `MoonDiffuseColor`, `SunAmbientColor`, and `SunDiffuseColor` DWORDs. The `MoonAmbientColor` and `SunAmbientColor` label references occur at `0x140361f16` and `0x140361f64` in that function. `CNWArea::CNWArea` at `0x140296a40` zero-initializes the stored light-direction vectors at `+0xac` and `+0xcc`; the area GFF contains no matching direction labels.
- `CNWSArea::GetAreaLightDirection` at `0x14035e5a0` returns those vectors for indices `0` and `1`. `CNWSArea::SetAreaLightDirection` at `0x140367d10` stores them, and `ExecuteCommandSetAreaLightDirection` at `0x14053dc50` normalizes a script-supplied vector before calling the setter. Thus static ARE data alone cannot recover a runtime diffuse direction.
- `LightManager::ControlLightsFade` at `0x14007ddb0` fades active `PartLight` records using `DeltaT`, separate per-light fade values, and `GetLightFadeSpeed`. Its observed call to `SetLightGL` is at `0x14007e687`.
- `SetLightGL` at `0x140080c10` converts PartLight colors with `RenderInterface::GetColorSpaceFromSRGB`. For point lights it stores radius-derived constant attenuation using `DAT_140d862a4 / (2 * radius^2)`; the Ghidra data item at `0x140d862a4` is `9.0` (`0x41100000`). `GetLightAdjustedColor` (`0x14007f380`) and `GetLightAdjustedRadius` (`0x14007f480`) also apply renderer-setting-dependent adjustments.
- `LightManager::GetEmitterLighting` at `0x14007ee50` accumulates in-range PartLights with linear distance attenuation, adds headlight and two manager-level area-light contributions, and clamps each resulting channel to `1.0`. It is called from `RenderSinglePass` at `0x1400d1c99` and `0x1400d1e57`, and from `RenderEmitter` at `0x140063092`; emitters consume lighting rather than implicitly creating world lights.
- `LightManager::GetShadowLights` at `0x14007f840` is called by `Scene::RenderSinglePass` at `0x1400d111b` and `0x1400d1135`; `BSPCreateStaticProjections` also calls it at `0x1400d7fee`. `RenderSinglePass` (`0x1400d0f10`) contains separate dynamic and static shadow stages. These call paths do not establish that a single Three.js PCF map reproduces the target’s shadow technique.

Implementation consequence: ARE RGB DWORDs are decoded from NWN BGR storage and converted from sRGB; model point lights use the verified radius attenuation constant, and MDL shadow flags feed Three.js shadow maps. The target's runtime area-light direction must currently remain unavailable when not supplied by a script/message; assigning a fixed vector would be an unsupported inference. Static/dynamic shadow pass parity, per-light filtering, and all environment-map material bindings remain open.

### Environment-map reflection path

- `PartTriMesh::Draw` (`0x1400a24c0`) uses `Material::HasEnvMap` (`0x140083550`), which returns whether the material's environment-texture pointer at `+0x40` is non-null. The environment-mapped branch calls `RenderEnvironmentMapped` (`0x1400a45c0`).
- `RenderEnvironmentMapped` prefers a per-model/material environment texture (`+0x480` or material `+0x40`); when that is null, it falls back to `currentscene + 0x1e8`. It binds the environment texture and enables the environment-map render state before the flat mesh draw. The stock `_sm` shader variants supply `ENVIRONMENT_MAP=1`; bit `0x40000` selects that variant.
- Reference validation: xoreos reads tileset `[GENERAL] EnvMap` and texture TXI `envmaptexture`; its texture manager uses cube reflection mapping for cube images and sphere mapping for 2D images. The CEP `ttr01` set resolves `EnvMap=ttr01__ref01`, but the ten tile bitmap TXIs checked for this area contain no `envmaptexture` override, so it is not yet an observable reflection case.

Inference/open item: the material opt-in and scene fallback are established, but exact EE texture binding, environment-map intensity, and reflection eligibility by material state still need mapping before enabling reflections broadly. Environment mapping is confirmed in NWN:EE `89.8193.37-17`; a viewer-side reflection implementation is not yet present.

These findings are from Ghidra decompilation and reference/disassembly queries against NWN:EE `89.8193.37-17` in the existing Ghidra 11.3.2 project. No Ghidra database edits were made for this shader pass.

### Skinned mesh draw path

- `PartSkin::Draw` (`0x1400deb40`) checks `PartTriMesh::IsPartRenderable`, performs the part draw setup, retrieves its `VertexPrimitiveSkinned`, and calls `RenderSkinned` at `0x1400deb7c`.
- `RenderSkinned` (`0x1400e0410`) gathers the part hierarchy's bone transforms with `GatherBones` (`0x1400df000`) and calls `ExecuteSkinGPU` at `0x1400e0636`. The inspected `GatherBones` code accumulates positions and quaternions recursively through child parts.
- `ExecuteSkinGPU` (`0x1400deb90`) processes at most 64 bone slots, composes a transform per available bone, and calls `RenderInterface::SetBoneMatrix` at `0x1400dee43`. The renderer implementation (`0x1400b6950`) rejects indices above 63, transposes each matrix, and stores it in the renderer's bone array. Shader reflection resolves `skinmesh` and `m_bones[0..63]`, matching the 64-bone compile limit.
- After enabling render state `0x15`, `ExecuteSkinGPU` selects the normal `RenderFlat` or `RenderEnvironmentMapped` path according to material/environment-map state. The evidence supports vertex-shader skinning through bone uniforms, not a compute-shader pass. State bit `0x15`'s semantic name remains **Open**.
- `RenderSkinned`'s virtual call at `0x1400e044f` is `PartSkin::PostProcess` (`0x1400df860`, PartSkin vtable slot 27 / byte offset `0xd8`). It gathers the inline Part list, resolves each of the four `SkinVertexWeight` bone names to a part index, remaps valid indices to compact GPU slots, writes the 4-component weight/index streams, and fills the 64-entry slot-to-bone map. Zero weights and invalid indices become zero / `-1` entries.
- The stock PC vertex shader path in `data/base_shaders.bif` (`vslit` -> `inc_standard` -> `inc_common`) gates skinning on `skinmesh == 1`. For each positive component of `vWeight`, it adds `m_bones[int(vIndex.component)] * vPos * vWeight.component`; normals and tangents use the corresponding `mat3(m_bones[index])` transform. This connects PartSkin preprocessing -> `vIndex`/`vWeight` -> 64 `m_bones` uniforms -> weighted vertex position -> the existing flat/environment draw and GL submission path.

The viewer parses the `0xC0` skin extension, per-vertex weight/index streams, bone reference arrays, and slot map. The initial preview applied mapped weights through static hierarchy matrices; the [animation foundation](model-animation.md) now updates that approximation after bone playback. Exceptional/unmapped skin variants and exact inverse-bind handling remain **Open**.

### Animated pose evaluation

- `Scene::Animate` (`0x1400c5210`) walks its registered animatable list and dispatches `Animate(deltaTime)` through virtual slot `+0x28`.
- `Gob::Animate` (`0x14004dbd0`) advances its `AnimRun` records, handles loop/end state, then calls `AnimateHierarchy` (`0x14004fe90`) with the runtime root `Part`, the active `Animation`'s root `MdlNode`, and the run's time/blend values. It also emits animation events crossed during the updated interval.
- `AnimateHierarchy` recursively matches child parts to model nodes by their node IDs (`Part +0x30` against `MdlNode +0x34`) and invokes the node's embedded function pointer at `+0x18`. `MdlNode` installs `MdlNodeControl` (`0x1400926c0`) there; this is not a C++ vtable dispatch.
- `MdlNodeControl` samples typed controller curves through `NewController::GetFloatValue` (`0x1400512c0`), `GetVectorValue` (`0x140051750`), and `GetQuaternionValue` (`0x140051530`). Scalar/vector channels interpolate between keys (including Bezier curves when flagged); quaternion channels use slerp. The controller's target offset selects fields in the runtime `Part` record.
- `Part::Animate` (`0x14004e9e0`) also dispatches per-part animation callbacks. `MdlNodeAnimMeshControl` (`0x140092430`) updates dynamic animated-mesh vertex channels independently of skeletal transforms.
- These updates precede the existing `GatherBones` -> `ExecuteSkinGPU` path: the hierarchy's animated transforms become the per-slot matrices consumed by the weighted vertex shader. Engine-side animated skin evaluation is statically connected. The viewer now parses/runs representative transform/opacity tracks and inherited clips; [implementation evidence](model-animation.md) separates those checks from still-open target visual parity.

### Frame presentation

`SwapBuffers` has a computed call from `FUN_140af3a60` at `0x140af3a6f`. Decompilation shows that this WGL wrapper passes the SDL window HDC to Win32 `SwapBuffers`; `FUN_140b2e470` installs it in the Windows video-device callback slot at `+0x190`. The frame call at `0x1400450a6` traces through `RenderInterface::SwapBuffers` (`0x1400bf390`) to `GLRender::SwapBuffers` (`0x1400bb640`, SDL call site `0x1400bb79a`), the SDL DYNAPI thunk `SDL_GL_SwapWindow` (`0x140ab16b0`), its implementation `FUN_140ad0ed0` (`+0x190` dispatch at `0x140ad0f4a`), and `SwapWindowBuffers` (`0x140af3a60`) to Win32 `SwapBuffers`. SDL video initialization selects the Windows device and sets the active-device pointer in `FUN_140ad4c60` (`0x140ad4dc7`); `FUN_140ab9cf0` builds its callback table. The presentation tail and SDL-window destruction are mapped. Normal HGLRC deletion is not invoked on the mapped shutdown path.

The code references confirm the SDL DYNAPI pointer, active video-device selection, and Windows callback-table registration described above; the SDL implementation itself performs the indirect `+0x190` callback dispatch.

### Renderer resource destruction

- The normal client-exit route releases Aurora before `SDL_Quit`: `SDL_main` calls `FUN_1406acd70` at `0x140046e16`, which dispatches to `FUN_1406e4c80`. PE unwind metadata bounds the latter at `0x1406e4c80-0x1406e5269`; its call to `DestroyCAurora` is at `0x1406e50c4`. When the Aurora reference count reaches zero, `DestroyCAurora` invokes the `CAurInternalGL` destructor (`0x140074c70`), which clears Aurora textures/resources and calls `SDL_DestroyWindow` at `0x140074cc1`. That destructor does not delete the GL context.
- `GLRender::Shutdown` (`0x1400bb560`), reached through `RenderInterface::Shutdown` (`0x1400bf380`) from `SDL_main`, deletes linked custom-program handles through the dynamically loaded `glDeleteProgram` pointer and frees their CPU-side records. The inspected shutdown body is limited to the custom-program table; it is not a general GL-object sweep.
- `CompileShader` (`0x1400adc20`) creates, compiles, and returns a shader handle on success; its `glDeleteShader` call is only on the compile-failure branch. `LoadShader` (`0x1400b45b0`) attaches the returned stages to a program, and the inspected `ConnectShaderData` (`0x1400add20`) links that program without calling the loaded `glDetachShader` or `glDeleteShader` pointers. The global pointer references found for those deletion/detachment functions are limited to the compiler failure path and auxiliary cleanup routines. This identifies missing explicit stage-object cleanup in the inspected success path; ownership/reclamation by driver behavior or other paths remains unverified.
- `VertexDataObject::~VertexDataObject` (`0x1400bc8f0`) calls `RenderInterface::DeletePool` for up to three pool IDs. `GLRender::DeletePool` (`0x1400afd20`) adds the ID to the reusable-ID list, updates accounting, and frees the pool's CPU allocation; it does not delete the pool's GL buffer name.
- `GLRender::UnlockPool` (`0x1400bbad0`) lazily obtains a buffer name with the dynamically loaded `glGenBuffers` pointer, stores it in the pool record at `+0x0c`, and uploads via `glBufferData`/`glBufferSubData`. The separate `GLRender::DeleteBuffer` (`0x1400afc00`) unbinds a currently bound buffer when needed and calls the loaded `glDeleteBuffers` pointer.
- The only code reference to the `glDeleteBuffers` function-pointer global found in the recovered Ghidra database is `GLRender::DeleteBuffer`; its callers are two auxiliary render-target cleanup routines (`0x140a71ef0`, `0x140a6fd50`). The pool deletion/resize/reuse routines do not call it. The pool allocator's `atexit` callback (`FUN_140d78680`, registered by `FUN_140015850`) walks the pool table and frees CPU allocations, without a GL buffer-delete dispatch in its body.
- This establishes a missing explicit `glDeleteBuffers` call in the observed pool cleanup path, not a confirmed runtime leak: the context may reclaim driver objects when it is destroyed, and static call-graph coverage cannot establish all process-exit behavior. The ordinary HGLRC deletion path remains separately unresolved; retain both as teardown coverage gaps pending runtime or broader lifecycle validation.

### Outer client frame loop and presentation

- `SDL_main` at `0x140046340` initializes SDL, creates the `Neverwinter Nights` window and GL context, then enters `while (g_bExitProgram == 0)`. Its call to `Update(nullptr)` is at `0x140046dc4`. On exit it calls `RenderInterface::Shutdown(1)` at `0x140046dec`, destroys the server, then calls `FUN_1406acd70` at `0x140046e16`. That wrapper enters the PE-bounded cleanup routine `FUN_1406e4c80` (`0x1406e4c80-0x1406e5269`), which calls `DestroyCAurora` at `0x1406e50c4`; when the Aurora reference count reaches zero, `CAurInternalGL::~CAurInternalGL` (`0x140074c70`) clears Aurora resources and destroys the SDL window. It then destroys the app manager/base and calls `SDL_Quit` at `0x140046e86` when SDL video remains initialized. `SDL_Quit` reaches `FUN_140abdf10`, whose subsystem shutdown calls `FUN_140ad50c0` for the active Windows video device; that routine destroys any remaining SDL windows through `FUN_140acfaa0`, releases display/device allocations, invokes the driver quit callback at device offset `+0x548`, and clears `DAT_141441148`. The registered Windows driver quit callback (`FUN_140aba6c0`) only shuts down Windows input/IME/COM state; it does not delete a GL context. Window teardown releases the HWND/HDC and auxiliary DC/bitmap resources, but the mapped normal exit path never invokes `SDL_GL_DeleteContext`. The thunk's registered callback at device offset `+0x198` does dispatch to `wglDeleteContext`, but no in-module caller was found. Thus normal shutdown has no observed explicit HGLRC deletion; this conclusion is from the recovered static call graph, not runtime observation.
- `Update` at `0x1400448b0` drains `SDL_PollEvent` through `WinMessageHandler`, handles Aurora reinitialization and frame limiting, then calls the client-app manager wrapper `FUN_1406ac470` at `0x140044de5`. That wrapper forwards to `FUN_1406db800` at `0x1406ac474`; the client worker updates world-time snapshots and delta time, updates resources, calls `AurMakeCurrent`, processes network/client state, and calls `CGuiMan::UpdateAndRender` (`0x1401f70e0`).
- `Update` calls the separate `CServerExoApp::MainLoop` wrapper at `0x140044e09`. The wrapper calls `CServerExoAppInternal::MainLoop` at call site `0x14055bcb4` (entry `0x140567380`). The internal loop is server/network/simulation work (`CNetLayer`, `CServerAIMaster`, `UpdateClientGameObjects`, resource/config updates), not the client frame scheduler.
- After those updates, `Update` calls `BeginScene` at `0x140044eb6`, draws posted strings through `AurRenderStrings`, calls `EndScene` at `0x14004509a`, and presents through `SwapBuffers(g_pWindow)` at `0x1400450a6`. The post-present app-manager helper call is at `0x1400450c8`.
- `FUN_1406db800` calls `CGuiMan::UpdateAndRender` at `0x1406dc26a` after the gameplay module has rendered. The GUI manager iterates its `CSceneView` list at `this +0x18`: scene animation is dispatched at `0x1401f7491`, then the camera at view `+8` invokes `Camera::RenderScene` through slot `+0x10` at `0x1401f75df`. `CGuiMan::Initialize` (`0x1401f5cd0`) creates `Overlay` and `MouseOverlay`; `CSceneView::CSceneView` (`0x1401f37f0`), `CGuiPanel::Activate` (`0x1401fbe70`), `CGuiPanel::CreateSceneView` (`0x1401fc230`), and `CGuiViewport` (`0x1401ecab0`) create GUI scene/camera pairs. These are separate from the gameplay module's camera dispatch described above.
- The renderer abstraction's `SwapBuffers` call is connected to the outer frame and to the installed Win32/WGL callback through SDL's active video-device function table, as detailed above.
- `NewCAurCamera` (`0x140059f70`) serves both GUI constructors and the gameplay module's initialization call at `0x1407cd3b9`. `CGuiPanel::RenderSceneViewFirst` (`0x1401fc940`) and `RenderSceneViewLast` (`0x1401fc9b0`) only reorder GUI views. The gameplay module instead invokes its camera directly at `0x1407d03ae`; no GUI-view registration edge is required.

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

This establishes a per-scene camera -> Scene::Render -> collect parts -> RenderSinglePass -> draw-bucket -> PartTriMesh::Draw chain. Gameplay enters it through the module-owned camera, independently of the GUI `CSceneView` loop. Bucket numeric meanings should remain provisional until each `DrawBucketManager` classification and consumer are cross-checked.

## Inferences (not yet confirmed)
The client-frame trace connects gameplay and GUI rendering to presentation. No registration of the gameplay camera in a GUI `CSceneView` is needed: module update draws that camera directly. The absence of an observed normal HGLRC deletion call is static evidence, not proof of complete cleanup behavior across all indirect paths or process-exit handlers.


- NWN:EE's Windows renderer uses WGL/OpenGL rather than Direct3D for this target build.
- Some functions newer than the statically imported OpenGL entry points may be resolved dynamically through `wglGetProcAddress`.
- `RenderVertexStreamData` sits below multiple specialized rendering paths; finding its callers' callers should lead toward world-scene orchestration.

## Next probes

1. Validate a moving gameplay pose and complete renderer-resource destruction coverage; preserve the original binary/project as read-only inputs.
2. Map shader source selection, uniform setup, texture upload/sampler semantics, and the remaining environment/shadow rendering branches.
3. Reconcile ASCII and binary MDL variants and dynamic object state with the viewer's bounded static implementation; decide whether animated-track evaluation is in scope.

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
