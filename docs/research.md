# Research baseline and evidence

The replacement reconstructs observable behavior. Decompiled pseudocode does not recover all original types, names, comments or source distinctions.

## Original target

| Field | Baseline |
| --- | --- |
| Executable | `../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe` |
| Build | NWN:EE `89.8193.37-17`, x64 PE |
| SHA-256 | `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a` |
| Existing project | `../FullDecomp/ghidra-projects/NWN-EE-8193.37-17.gpr` |
| Setup reference | `../FullDecomp/GHIDRA_MCP_SETUP.md` |

The parity audit independently hashed and opened this binary read-only. It did not perform fresh execution of every native function or complete campaign/server validation.

Keep the original executable and analysis inputs read-only. Do not patch or inject into the running game. No proprietary assets, credentials, captures or runtime logs belong in source control.

## Evidence discipline

Distinguish Observed, Inferred and Open. Retain target identity, procedure/call-site addresses, complete caller/initialization/cleanup coverage where needed, and validation source. An inferred semantic name is not an observed original type.

Use existing bounded dossiers before requesting another expensive whole-binary analysis. The pinned REA launcher is `scripts/rea-mcp.mjs`; `scripts/rea-session.mjs` supports a retained local session when appropriate. Inspect their current policy before invocation.

A parser test is not a player action. A sent request is not a server acknowledgment. An offline fixture is not a current original-server result. A screenshot is not sustained performance. Two replacement clients are not a native/replacement pair.

## Finding old research

The [archive manifest](archive/manifest.json) indexes all 990 original Markdown files by original path, title, size, SHA and canonical guide. The [archive reader](archive.md) displays an original note without restoring the file sprawl.

Existing raw JSON reports, original-instruction corpora, source manifests and failed receipts remain in place. The [November parity audit](../evidence/playable-parity-audit-2026-11-09.json) preserves detailed issue evidence and pre-cleanup hashes. A deleted Markdown path in that historical audit is resolved through the archive; its original hash must not be rewritten as if a new summary were the same evidence.
