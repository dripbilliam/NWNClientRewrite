# Native camera fade-plane frontier

Pinned original PE `nwmain.exe` SHA-256: `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

## Established path

`ManageSceneBSP` calls `FUN_1400d88b0` at `0x1400db560`. The helper asks the current camera for the `CameraFollow` behavior, reads its target world position and the camera position, and selects Scene `+0x1a0=2` if the horizontal magnitude reaches `0.4`; it calls camera primary virtual `+0x100=Camera::SetFadePlanes` at `0x1400d8c82`. Otherwise it selects Scene mode `1`. The setter at `0x14005b4a0` copies two planes to camera storage. This is the previously pinned `scene-bsp-frame-maintenance.md` evidence `ev_1c825c8f55c31a94226bfa2a7e0fc64e0b1632389b48047f57855d2d5e336c53` and setter `ev_5170e3694448c595b9931f217157e6f07b3742d81d580deffa735578d4f84cf7`.

The saved `ProcessTriMeshParts` decompilation in `tools/native_parity/visibility/evidence/native-tile-fog-placement-and-membership-v1.json` takes the special fade path when `Scene::geomFadeEnabled==4`, or when it is `1` and Scene mode is `2`. The mode-1 tile test uses camera floats `+0x500`, `+0x504` and `+0x50c`; the saved body does not explain how `FUN_1400d88b0` constructs those values. `Scene::SetGeomFadeProperties(int)` at `0x1400d3380`, saved in `native-presentation-procedures-v2.json` row `sceneFadeProperties`, accepts only values 1, 2 and 4 and stores the accepted value in `geomFadeEnabled`. The setter's existence does not prove which value the running client selects or who calls it.

The user's original `settings.tml` currently records `graphics.keyholing.enabled=true`, `disables-camera-collisions=true`, min diameter `0.4`, max diameter `0.9`, and min Z offset `1.0`. No pinned call/data edge connects that schema to `Scene::geomFadeEnabled`; the coincident `0.4` value must not be treated as proof of equivalence.

A direct printable-string scan of the SHA-verified PE finds `keyholeCanDissolve`, `keyholeDiameterMin`, `keyholeDiameterMax`, `keyholeMinZOffset` and `graphics.keyholing.*` setting keys (file offsets `0xd8b0d8..0xd8b120` and `0xe28829..0xe28939`). It also finds the separate decorated `Scene::geomFadeEnabled` symbol at `0x126fa6d`. These are identities, not a producer-to-consumer call edge; none establishes that keyholing writes the geometry-fade mode.

## Exact unresolved boundary

The saved evidence lacks the full helper arithmetic and machine instruction sequence from `0x1400d88b0` through its `SetFadePlanes` call. It does not establish the two planes' coefficients, sign convention, offsets or world/camera coordinate space. It also lacks the native setting producer or a captured runtime value for `geomFadeEnabled`. No faithful client fade-plane implementation can be derived from the `0.4` branch and setter address alone.

The REA session reported the correct pinned binary, Ghidra 12.1.4 and no observed active provider, but `analyze_function(0x1400d88b0)`, `procedure_references(0x1400d3380, incoming)` and `address_to_file_offset(0x1400d88b0)` all failed to return within bounded waits and were canceled. The PE was present and hash-pinned; no installed local disassembler or retained helper decompilation was found. This is a tool/evidence boundary, not evidence that the planes or setting path do not exist.

Next useful capture: a bounded function dossier or disassembly for `0x1400d88b0` (including argument stores before `0x1400d8c82`), plus incoming references or callers of `Scene::SetGeomFadeProperties`, and one runtime setting receipt. Until then, retain the NWN-80 tilefade cap owner as unimplemented; a static always-on cap draw would not follow the native active-fade gates.
