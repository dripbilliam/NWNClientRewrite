# Initial Windows Executable Inventory

**Collected:** 2026-10-10
**Source directory:** `../FullDecomp/NwnRootInstall/bin/win32`
**Method:** Windows file-version metadata and `Get-FileHash -Algorithm SHA256`. No files were modified.

| Executable | Product version | File version | Size (bytes) | SHA-256 | Initial scope |
|---|---|---|---:|---|---|
| `nwmain.exe` | `89.8193.37-17` | `89.8193.37-17` | 21,071,872 | `3B7CB1252E0EDB2CE22D7971F333AADE027039AE30A45B4BC64732C3E6BEC73A` | Primary game client; Ghidra project exists |
| `nwserver.exe` | `89.8193.37-17` | `89.8193.37-17` | 12,586,496 | `98951511AE7D06A251355F12D4F3E4B96269A2414FA3058E641AFD70098690F6` | Multiplayer server; project/import status unknown |
| `nwtoolset.exe` | `1.0.0.0` | `1.5.0.5` | 12,201,984 | `4C156DE898817518E8A97F5D989592894D3C8F48B71D27E2A8B89500CD230F24` | World/module authoring tool; project/import status unknown |
| `nwhak.exe` | `1.0.0.0` | `1.0.4.0` | 3,282,944 | `231ACE10B91D3065FEF399C497828C7933C27553A03F88C9B38A222BD10A5B76` | Resource/archive utility; role to verify |
| `oalinst.exe` | `2, 0, 3, 0` | `2, 0, 3, 0` | 782,336 | `2717D90CE92A7CEBADCA049B1C8B0CBB6DAE7B3D35A4F12714B69D9728DE1BA1` | Bundled OpenAL installer; ancillary rather than core game runtime |

## Scope notes

This is an initial inventory of `.exe` files in the installed Windows `win32` directory, not a complete inventory of the game. Runtime DLLs, plugins, data archives, scripts, resources, other platform builds, and server deployment variants remain to be inventoried. Architecture and dependency relationships for every executable are also unverified.

The version metadata distinguishes the NWN:EE client/server from the separately versioned toolset and utilities. Do not assume all components share the same source tree, compiler, or binary layout. Use these hashes to ensure future Ghidra imports and notes refer to the same installed files.