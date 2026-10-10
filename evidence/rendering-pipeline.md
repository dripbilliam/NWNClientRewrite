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

This establishes a native Win32/OpenGL render path. `wglGetProcAddress` makes dynamic GL extension loading a strong lead, but the exact loaded extension set remains **Open** until its caller and lookup strings are traced.

### Geometry submission

`GLRender::RenderVertexStreamData` begins at `0x1400b5c20`; an imported `glDrawElements` computed call is at `0x1400b5d59`.

The decompilation shows this routine:

1. Applies a `VertexStreamDataObject` through `SetVertexStreamDataObject`.
2. Selects a shader/program based on object flags, renderer state, and whether a custom program is active.
3. Uses `glDrawArrays` when the object's field at offset `+8` is zero.
4. Otherwise uses `glDrawElements` with `GL_UNSIGNED_SHORT` (`0x1403`) and an index offset derived from the fourth argument.
5. Clears selected renderer state after submission.

The function has callers including `DrawLines`, `RenderBox`, `DrawFromVerts`, `DrawBoundingBox`, and `RenderDrawableSquares`. It is a low-level geometry helper used by multiple rendering/UI/effect paths; this alone does not identify the main world-scene traversal.

### Frame presentation

`SwapBuffers` has a computed call from `FUN_140af3a60` at `0x140af3a6f`. Decompilation of `FUN_140af3a60` shows a small wrapper that calls `SwapBuffers` with an HDC reached through its second argument, then calls an error-reporting function if the Win32 call fails. The higher-level caller/frame loop remains **Open**.

## Inferences (not yet confirmed)

- NWN:EE's Windows renderer uses WGL/OpenGL rather than Direct3D for this target build.
- Some functions newer than the statically imported OpenGL entry points may be resolved dynamically through `wglGetProcAddress`.
- `RenderVertexStreamData` sits below multiple specialized rendering paths; finding its callers' callers should lead toward world-scene orchestration.

## Next probes

1. Trace `ChoosePixelFormat`, `SetPixelFormat`, `wglCreateContext`, `wglMakeCurrent`, and `wglDeleteContext` references to recover context lifecycle. The WGL context functions may be imported or dynamically looked up.
2. Trace callers of `FUN_140af3a60` to identify frame presentation and the main loop boundary.
3. Walk upward from world-specific callers of `RenderVertexStreamData`; separate world geometry from GUI, text, debug, and effects.
4. Find `wglGetProcAddress` callers and the associated GL procedure-name strings; inventory shader, buffer, and framebuffer extensions.
5. Record each path with function entry/call-site addresses and distinguish direct evidence from interpretation.

## Reproduction

The existing helper is `../FullDecomp/tooling/NWN-Ghidra.ps1`. `Status` confirmed the Ghidra process and MCP endpoint were online during this inspection. Relevant HTTP bridge reads were `/imports`, `/xrefs_to`, `/function_xrefs`, and `/decompile`; no mutating endpoint was used.