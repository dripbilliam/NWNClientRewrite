# NWN:EE Reverse-Engineering Workspace Instructions

- Treat `../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe` and the existing Ghidra project as read-only research inputs unless the user explicitly authorizes changes.
- Do not patch, inject into, or alter the running game. Research tasks should use static Ghidra analysis or explicitly authorized read-only runtime observation.
- Keep evidence, inferences, and open questions distinct. Include target build, function address, call-site address, and validation source for binary findings.
- Do not invent semantic names or types. Record proposed names in notes and make Ghidra database edits only when the evidence is strong and the edit is requested or clearly part of the agreed workflow.
- Do not copy proprietary binaries or game assets into this workspace. Link to the existing files by relative path.
- Do not claim a subsystem is fully decompiled based only on pseudocode output; map callers, data flow, initialization, error handling, cleanup, and validation.
- Keep research changes focused in this workspace and avoid unrelated changes in the original `FullDecomp` workspace.
- Native research can use the pinned REA launcher `scripts/rea-mcp.mjs` (project MCP server `rea_nwn`). It keeps imports in temporary OS directories and exposes only the read-only native research policy. In an already-running agent without refreshed MCP tools, `scripts/rea-session.mjs` provides a persistent local MCP client; reuse its session to avoid repeated whole-binary imports. Keep original-code oracles and explicit ABI/type checks alongside REA pseudocode. See `evidence/rea-isolated-trial.md` for the measured validation and limitations.
