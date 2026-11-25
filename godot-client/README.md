# Native client launch guide

The normal client is native desktop Godot. It opens Main Menu; the user chooses Multiplayer and selects a server. No public-server connection happens merely by starting the normal launcher.

From the repository root:

```powershell
npm install
.\godot-client\tools\setup.ps1
.\godot-client\join-native.ps1
```

Setup builds and verifies the Windows client engine, including the rig pose
optimization and render-thread shutdown fix, from pinned sources. The first
build takes several minutes. Ordinary launches and prepared release packs use
that engine automatically. Godot's official editor remains available for
development.

Setup requires PowerShell 7 and Git for Windows. Running the client also requires
a compatible Node.js installation, MSVC x64/Windows SDK tools, and an owned
NWN:EE installation. The engine inputs are in `client-runtime-lock.json` and
the editor version is in `runtime-lock.json`.

Setup also refreshes the installed NWSync reader when the SQLite and Zstandard
source trees used by `scripts/build-content-reader.ps1` are available. The
reader then validates and reuses an already-resident installed manifest.

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

To try combined particle simulation reuse with the standard client, add
`-ParticleSimReuse` to the PowerShell launcher. It enables quaternion basis
reuse and eligible pool traversal fusion for that launch. This can improve
movement and has shown slower idle frames in a shadows-off test.

```powershell
.\godot-client\join-native.ps1 -PerformanceRuntime standard -ParticleSimReuse
```

For direct bootstrap launches, rebuild the kernel through
`godot-client/tools/ensure-particle-kernel.ps1` and pass `--particle-sim-reuse=on`.

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
