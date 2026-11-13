# NWNAnalog

An independent NWN: Enhanced Edition client using native desktop Godot and original game resources. The goal is to play alongside unmodified original clients on unchanged original servers.

**Playable multiplayer features exist; full native-client parity, performance and migration remain incomplete.** The original server owns authoritative outcomes. Godot owns presentation, resource preparation and gameplay UI; Node and a windowless Electron credential bootstrap remain transitional services.

## Run

Windows/PowerShell development setup, from the repository root:

```powershell
npm install
.\godot-client\tools\setup.ps1
.\godot-client\join-native.ps1
```

Main Menu opens without automatically joining a server. A user-owned NWN:EE installation, credentials and required server content are needed; proprietary resources are not included.

See the [native launch guide](godot-client/README.md) for the owned-local route, runtime flags and reference client.

## Project map

| Area | Entry point |
| --- | --- |
| Documentation | [Topic guides](docs/README.md) |
| Remaining work | [Playable parity and Linear issues](docs/parity.md) |
| Runtime ownership | [Architecture](docs/architecture.md) |
| Setup and checks | [Development](docs/development.md) |
| Native frontend | `godot-client/` |
| Transitional protocol/services | `electron/`, `src/network_*.js` |
| Reference Electron/Three.js client | `src/`, `electron/` |
| Native extensions | [Build reference](godot-client/native/README.md) |
| Entity inspection API | [Entity API](godot-client/ENTITY-API.md) |
| Original binary and methods | [Research](docs/research.md) |
| Static wiki | [Build and preview](wiki/README.md) |

## Current capability and limits

Scoped original-server evidence covers admission, character creation/selection, movement, combat/casting, inventory/equipment, merchants, player trade, chat/dialogue, native menus, server NUI and area/server travel. Coverage varies by feature, class, content and entry path.

Remaining work includes connection reliability, incomplete action/UI branches, broad original/replacement-client acceptance, visibility/effects/audio, dense-scene loading/frame consistency and later fully native services/offline campaigns. A component pass or successful retry does not establish complete parity.

The [parity audit](evidence/playable-parity-audit-2026-11-09.json) records the findings and evidence; [NWN-13](https://linear.app/nwnanalog/issue/NWN-13/complete-playable-parity-with-the-base-native-client) tracks the work.

## Documentation history

The former per-feature goals, handoffs and checkpoint logs are consolidated into topic guides. All 990 pre-cleanup Markdown files are preserved in one verified [compressed archive](docs/archive.md), including their exact source bytes and hashes. Read any old note on demand without restoring the file sprawl.

Update an existing guide and the relevant issue rather than adding another milestone Markdown file.
