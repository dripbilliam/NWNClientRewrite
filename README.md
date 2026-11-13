# NWNAnalog

An independent, multiplayer only Neverwinter Nights: Enhanced Edition client built with native desktop Godot. Its purpose is to make fair client side modding possible while playing alongside unmodified original clients on unchanged original servers. 

**This is not a piracy project. No NWN:EE base game files are included. You need your own legitimate game installation and a valid multiplayer CD key.** NWNAnalog reads the base game resources you already have; it does not supply a copy of the game.

**Multiplayer only for the foreseeable future.** Single-player campaigns (unless you multiplayer host them to just yourself and join with this client) and offline play are not supported and are outside the current development scope.


## Development

This initially started out as something I hand made using Node and Electron. To which, I managed to actually get working, but Three.js was not able to quickly enough deal with unpacking resources, transforming them into a format that it could use and render the world withoug dropping below 30 fps. Due to this, a good portion of the dev process *after* this fact was handed over to AI, much more so when it came to the field of optimizing that code translated into Gadot. 

Due to my lack of fluency with Gadot, there is a good chance anything that needs to be concerned with CPU frametime issues is not written or even drafted conceptually by me. However, while alot of the code I written has been bastardized by the AI, it does frankly run 10000000% faster and better.

Also, a large portion of the workload here was reverse engineering the ENTIRE rendering flow. From request, to load, to transform, to overlay into finally rendering order and onto the screen. At such a time I feel it proper, I may release a Ghidra debugger file that annotates alot of the static decompiled code for others to potentially bunny hop off of.

At this time I use a Linear board, but as those cannot be publicly shared, ticket work and progress can be seen here:
https://github.com/users/dripbilliam/projects/3

## Why this client exists

The goal is to let players change how their client presents and controls the game, while respecting server rules. Examples of the customization we want to enable include:

- Free cam and noclip detached camera movement, to setup amazing photos.
- (re)Shaders perhaps?
- Buff Timer Icons for important things like making sure short term buffs have an obvious and explicit (second) timer for you to watch.
- Different inventory and bag layouts, organization and interaction, while preserving server authority.
- Alternative dialogue presentation, text layouts and input workflows.

These are examples of the intended modding direction, not a promise that every customization is available today. Fair client side modding must respect server rules and the information the client is allowed to receive. The original server remains authoritative over gameplay outcomes.

## Requirements and game ownership

- Your own legitimate NWN:EE installation containing the base game resources.
- A valid multiplayer CD key for authentication with original servers.
- The Windows development tools described below and in the [development guide](docs/development.md).

**No base game files or valid CD keys are provided by this project.** NWNAnalog can read the base game files from the installation you supply. Cloning this repository does not give you a playable copy of NWN:EE or replace game ownership. Server content downloads are separate from the base game and come from the relevant server or content provider.



## Run

I will note at this time, this project is not *built* for use outside the dev enviroment. It is here right now just to show what there currently is. In the future a proper download and executable will be provided. 


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

Scoped original server evidence covers server entry, character creation/selection, movement, combat/casting, inventory/equipment, merchants, player trade, chat/dialogue, native menus, server NUI and area/server travel.

Remaining work includes visibility/effects/audio, dense scene loading/frame consistency. 


## What this repository provides

NWNAnalog provides client code, development tools, documentation and research/test evidence. Screenshots and reports may show output from an owned game installation; they do not supply the original game files needed to run it.

**This is not a piracy project or a distribution of NWN:EE.** Original game executables, game archives, modules, models, textures and audio must come from your own installation. You still need to own the game and use a valid multiplayer CD key.

## Credits and research references

These projects were used as research/reference material. Thank you to their authors, maintainers and contributors for their work on Neverwinter Nights tooling, engine knowledge and file formats:

- [Neverwinter.nim](https://github.com/niv/neverwinter.nim), by Bernhard Stoeckner (niv) and contributors: Nim libraries and tools for NWN:EE data files and NWSync. [Upstream MIT license and copyright notice](https://github.com/niv/neverwinter.nim/blob/master/LICENCE).
- [NWNX:EE Unified](https://github.com/nwnxee/unified), by the NWNX:EE maintainers and contributors: the Neverwinter Nights Extender: Enhanced Edition framework and its engine interfaces. [Upstream GPLv3 license](https://github.com/nwnxee/unified/blob/master/LICENSE).
- [xoreos](https://github.com/xoreos/xoreos), by the xoreos team and contributors: an open-source reimplementation of BioWare's Aurora engine and its derivatives. [Upstream GPLv3-or-later license](https://github.com/xoreos/xoreos/blob/master/COPYING) and [authors and notices](https://github.com/xoreos/xoreos/blob/master/AUTHORS).

The license links describe the upstream reference projects and preserve a route to their original notices.


