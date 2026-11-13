# NWNAnalog

An independent, multiplayer only Neverwinter Nights: Enhanced Edition client built with native desktop Godot. Its purpose is to make fair client side modding possible while playing alongside unmodified original clients on unchanged original servers. 

**This is not a piracy project. No NWN:EE base game files are included. You need your own legitimate game installation and a valid multiplayer CD key.** NWNAnalog reads the base game resources you already have; it does not supply a copy of the game.

**Multiplayer only for the foreseeable future.** Single-player campaigns (unless you multiplayer host them to just yourself and join with this client) and offline play are not supported and are outside the current development scope.

## Why this client exists

The goal is to let players change how their client presents and controls the game, while respecting the server's rules. Examples of the customization we want to enable include:

- Free cam and noclip detached camera movement, to setup amazing photos.
- Different inventory and bag layouts, organization and interaction, while preserving server authority.
- Alternative dialogue presentation, text layouts and input workflows.

These are examples of the intended modding direction, not a promise that every customization is available today. Fair client side modding must respect server rules and the information the client is allowed to receive. The original server remains authoritative over gameplay outcomes.

## Requirements and game ownership

- Your own legitimate NWN:EE installation containing the base game resources.
- A valid multiplayer CD key for authentication with original servers.
- The Windows development tools described below and in the [development guide](docs/development.md).

**No base game files or valid CD keys are provided by this project.** NWNAnalog can read the base game files from the installation you supply. Cloning this repository does not give you a playable copy of NWN:EE or replace game ownership. Server content downloads are separate from the base game and come from the relevant server or content provider.



## Run

Windows/PowerShell development setup, from the repository root:

```powershell
npm install
.\godot-client\tools\setup.ps1
.\godot-client\join-native.ps1
```

Main Menu opens without automatically joining a server. Supply your own NWN:EE installation, valid CD key and required server content. This project does not distribute the base game or bypass the requirement to own it.

See the [native launch guide](godot-client/README.md) for the owned-local route, runtime flags and reference client.

Some development builds also use separately obtained third-party source checkouts for native helpers. The local `references/` directory is ignored by Git and is not included with this repository; a fresh checkout must obtain any such build inputs separately.

## Project map

| Area | Entry point |
| --- | --- |
| Documentation | [Topic guides](docs/README.md) |
| Remaining work | [Playable parity and Linear issues](docs/parity.md) |
| Public development board | [GitHub Kanban](https://github.com/users/dripbilliam/projects/3) · [Sync setup](scripts/linear-project-sync/README.md) |
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

**It is at this time mostly playable** 

Scoped original server evidence covers admission, character creation/selection, movement, combat/casting, inventory/equipment, merchants, player trade, chat/dialogue, native menus, server NUI and area/server travel. Coverage varies by feature, class, content and entry path.

Remaining work includes visibility/effects/audio, dense scene loading/frame consistency and migration of the remaining services. 

The [parity audit](evidence/playable-parity-audit-2026-11-09.json) records the findings and evidence; [NWN-13](https://linear.app/nwnanalog/issue/NWN-13/complete-playable-parity-with-the-base-native-client) tracks the work.

## What this repository provides

NWNAnalog provides client code, development tools, documentation and research/test evidence. Screenshots and reports may show output from an owned game installation; they do not supply the original game files needed to run it.

**This is not a piracy project or a distribution of NWN:EE.** Original game executables, game archives, modules, models, textures and audio must come from your own installation or separately obtained server content. You still need to own the game and use a valid multiplayer CD key.

## Credits and research references

These projects were used as research/reference material, rather than imported as client source code. Thank you to their authors, maintainers and contributors for their work on Neverwinter Nights tooling, engine knowledge and file formats:

- [Neverwinter.nim](https://github.com/niv/neverwinter.nim), by Bernhard Stoeckner (niv) and contributors: Nim libraries and tools for NWN:EE data files and NWSync. [Upstream MIT license and copyright notice](https://github.com/niv/neverwinter.nim/blob/master/LICENCE).
- [NWNX:EE Unified](https://github.com/nwnxee/unified), by the NWNX:EE maintainers and contributors: the Neverwinter Nights Extender: Enhanced Edition framework and its engine interfaces. [Upstream GPLv3 license](https://github.com/nwnxee/unified/blob/master/LICENSE).
- [xoreos](https://github.com/xoreos/xoreos), by the xoreos team and contributors: an open-source reimplementation of BioWare's Aurora engine and its derivatives. [Upstream GPLv3-or-later license](https://github.com/xoreos/xoreos/blob/master/COPYING) and [authors and notices](https://github.com/xoreos/xoreos/blob/master/AUTHORS).

The license links describe the upstream reference projects and preserve a route to their original notices.

## Documentation history

The former per-feature goals, handoffs and checkpoint logs are consolidated into topic guides. All 990 pre-cleanup Markdown files are preserved in one verified [compressed archive](docs/archive.md), including their exact source bytes and hashes. Read any old note on demand without restoring the file sprawl.

Update an existing guide and the relevant issue rather than adding another milestone Markdown file.
