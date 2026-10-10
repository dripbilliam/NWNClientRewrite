# NWN: Enhanced Edition Reverse-Engineering Workspace

This workspace tracks a subsystem-by-subsystem investigation of NWN: Enhanced Edition. The long-term objective is a comprehensive behavioral reconstruction, not a claim that Ghidra can automatically recover the original source code. Optimized binaries do not preserve original names, comments, types, or every source-level distinction; conclusions must be validated against code paths and runtime evidence.

## Target and existing analysis

- Target executable: `../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`
- Target build: NWN:EE `89.8193.37-17`, x64 PE
- Expected SHA-256: `3B7CB1252E0EDB2CE22D7971F333AADE027039AE30A45B4BC64732C3E6BEC73A`
- Existing Ghidra project: `../FullDecomp/ghidra-projects/NWN-EE-8193.37-17.gpr`
- Existing Ghidra version and bridge setup: `../FullDecomp/GHIDRA_MCP_SETUP.md`

The executable and Ghidra project are shared research inputs in the original `FullDecomp` workspace. Do not copy or re-import them here. Keep the binary unchanged. Avoid speculative Ghidra renames/types/comments; record evidence in this workspace first.

## Research workflow

1. Record the exact target/build and the evidence source for every finding.
2. Trace from imports/strings to callers, then through callers to subsystem boundaries.
3. Label statements as **Observed**, **Inferred**, or **Open**; include addresses and validation status.
4. Keep renderer, resources, protocol, scripting, and world simulation as separate tracks until their interfaces are demonstrated.
5. Validate hypotheses with independent call paths, runtime behavior, or known reference implementations before treating them as facts.

## Current entry points

- [Initial Windows executable inventory](evidence/binary-inventory.md)
- [First object-render milestone](evidence/first-object-render.md)
- [Research tracker](RESEARCH_TRACKER.md)
- [Initial OpenGL render-path findings](evidence/rendering-pipeline.md)

Ghidra label persistence is checked by [VerifyRendererLabels.java](scripts/VerifyRendererLabels.java). The PartTriMesh RTTI scan is in [InspectPartTriMeshVtable.java](scripts/InspectPartTriMeshVtable.java), and local snapshots under `backups/` are excluded from Git.

## Desktop model viewer

The Electron/Three.js viewer builds and launches with:

```powershell
npm install
npm start
```

Use **Open Assets** to choose one ASCII `.mdl` and any matching `.tga` bitmaps together. The viewer currently supports static trimesh nodes, parent transforms, face UVs, and local TGA textures. Binary MDL encodings, skin animation, emitters, and dynamic game state are not implemented.

To extract one named resource from the existing installation without unpacking an archive into this repository:

```powershell
py scripts/extract_key_bif_resource.py `
	'C:\path\to\NwnRootInstall\data\nwn_base.key' `
	'C:\path\to\NwnRootInstall' `
	plc_creats.tga `
	"$env:TEMP\plc_creats.tga" `
	--bif data/textures_02.bif
```
