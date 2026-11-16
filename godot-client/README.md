# Native client launch guide

The normal client is native desktop Godot. It opens Main Menu; the user chooses Multiplayer and selects a server. No public-server connection happens merely by starting the normal launcher.

From the repository root:

```powershell
.\godot-client\tools\setup.ps1
.\godot-client\join-native.ps1
```

An owned NWN:EE install/content is needed. Setup provisions the pinned Godot runtime and builds the Windows helpers; building those helpers from source requires MSVC x64 and Windows SDK tools. The pinned runtime is specified in `runtime-lock.json`.

## Launch routes

| Route | Purpose |
| --- | --- |
| `join-native.ps1` | Main Menu and normal native multiplayer flow |
| `join-godot.ps1` | Direct Godot original-server route and prerequisite check |
| `join-local.ps1` | Owned private-server launch and the verified pure graphical smoke check |

The owned-local route assumes the install/server under `../FullDecomp/NwnRootInstall` and a local profile on UDP 5121. Unsupported original-host diagnostic flags fail before starting a client or server.

## Configuration and preparation

[CLIENT-FLAGS](CLIENT-FLAGS.md) records historical configuration research. Use the current Godot menu and launch parameters for supported controls.

Normal gameplay rendering uses the integrated Godot profile. Retain the user's preferences, including particle settings; effects-off results do not establish full-effect parity.

Main Menu → Options → Prework offers Prepare assets, Cancel preparation, Clear saved prework and saved-file inspection for selected installed/downloaded content. Preparing content is separate from joining.

## Development references

Run the offline NWN-79 Godot/PowerShell regression subset:

```powershell
.\godot-client\tools\nwn79\run-focused-tests.ps1
```

This command runs focused Godot and PowerShell checks plus the Godot-only source guard. Private-server and graphical acceptance use separate bounded fixtures.

- [Architecture and ownership](../docs/architecture.md)
- [Development and validation](../docs/development.md)
- [Remaining parity work](../docs/parity.md)
- [Current performance](../docs/performance.md)
- [Entity API](ENTITY-API.md)
- [Compiled extensions](native/README.md)
- [Archived feature notes](../docs/archive.md)

The normal `join-native.ps1` path delegates to the Godot-owned session. Godot owns resource/model/texture preparation, animation, rendering, UI, networking and protected settings operations on that path. Run `join-godot.ps1 -CheckOnly` to verify its prerequisites without starting the client. [NWN-79 progress](tools/nwn79/godot-only-session-progress.md) records verified private-server coverage and remaining acceptance work. Unsupported original-host diagnostic modes now reject before startup; NWN-79 acceptance remains in progress.

Feature tests have separate entry paths and limits. Normal-entry evidence, real original-server outcomes, paired original-client checks and representative visual/performance acceptance are required before declaring parity.
