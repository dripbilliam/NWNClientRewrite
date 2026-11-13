# Native client launch guide

The normal client is native desktop Godot. It opens Main Menu; the user chooses Multiplayer and selects a server. No public-server connection happens merely by starting the normal launcher.

From the repository root:

```powershell
npm install
.\godot-client\tools\setup.ps1
.\godot-client\join-native.ps1
```

A compatible Node.js installation, MSVC x64/Windows SDK tools and an owned NWN:EE install/content are needed. The pinned Godot runtime is specified in `runtime-lock.json`.

## Launch routes

| Route | Purpose |
| --- | --- |
| `join-native.ps1` | Main Menu and normal native multiplayer flow |
| `join-local.ps1` | Existing owned-local development profile |
| `run.ps1` | Historical captured/offline viewer; not normal multiplayer acceptance |
| Root `npm start` | Preserved Electron/Three.js reference frontend |

The owned-local route assumes the install/server under `../FullDecomp/NwnRootInstall` and a local profile on UDP 5121. Inspect its current options before using it; existing servers and user sessions must be preserved.

## Configuration and preparation

[CLIENT-FLAGS](CLIENT-FLAGS.md) documents supported controls. Inspect the actual startup manifest and effective owners; engine/thread/light/collision/loading choices are independent.

Normal gameplay rendering uses the integrated profile. `-RenderProfile legacy` remains a diagnostic rollback. Retain the user's preferences, including particle settings; do not count effects-off results as full-effect acceptance.

Main Menu → Options → Prework offers Prepare assets, Cancel preparation, Clear saved prework and saved-file inspection for selected installed/downloaded content. Preparing content is separate from joining.

## Development references

- [Architecture and ownership](../docs/architecture.md)
- [Development and validation](../docs/development.md)
- [Remaining parity work](../docs/parity.md)
- [Current performance](../docs/performance.md)
- [Entity API](ENTITY-API.md)
- [Compiled extensions](native/README.md)
- [Archived feature notes](../docs/archive.md)

Godot owns resource/model/texture preparation, animation, rendering and UI. Transitional Node/Electron services still own protocol/authentication/download/credential responsibilities. This is unfinished multiplayer-first migration, not a complete native single-player campaign replacement.

Feature tests have separate entry paths and limits. Normal-entry evidence, real original-server outcomes, paired original-client checks and representative visual/performance acceptance are required before declaring parity.
