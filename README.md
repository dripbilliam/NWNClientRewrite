# NWN: Enhanced Edition — Replacement Client & Reverse Engineering

This repository contains a replacement NWN: Enhanced Edition client and the
binary research behind it. The active client runs in **native desktop Godot**,
loads original NWN resources, and connects to original NWN servers. The goal is
behavioral compatibility with the original client, including playing alongside
unmodified clients on unchanged servers.

**Status: playable multiplayer features with scoped local-server validation;
full original-client parity and migration remain incomplete.** This is an
experimental client, not yet a complete replacement for `nwmain.exe`.

Status reviewed: **2026-10-31**. “Original client” or “original binary” below
means NWN's `nwmain.exe`; “native Godot” means this project's replacement.
Earlier project history reviewed and added: **2026-11-01**.

## From Electron to Godot

The first desktop replacement client was built with **Electron, Three.js and JavaScript**.
It grew from an ASCII/binary model viewer into a module explorer with animation,
gameplay UI, a partial NWScript/game simulation, combat and multiplayer support.

That Electron/Three.js frontend was **phased out as the primary client because
of frame-time problems**. Dense worlds, hierarchy updates, lighting/shadows,
particles and rendering submission exposed substantial costs and hitches.
The move to native Godot was recorded in commit `05f769b` on **2026-10-24**.
The old client remains available as a reference and regression tool.

Godot now owns the desktop window, frame loop, original-resource loading,
model/texture preparation, scene construction, animation, rendering and gameplay
UI. The normal route constructs worlds directly from NWN resources, without
whole-area GLB conversion or a browser renderer. GDScript and C++ GDExtensions
share this work.

**Electron has not been removed from all dependencies.** A windowless Electron
bootstrap still unlocks Windows-protected credentials/settings, and a Node.js
process still handles authentication, protocol encoding/decoding, downloads and
replicated-state transport. Moving these remaining services into the native
client is unfinished. See [runtime ownership](godot-client/NATIVE-OWNERSHIP.md)
and [the direct entry](godot-client/NATIVE-SESSION-RENDER.md).

## Major milestones


| Period | Milestone |
| --- | --- |
| October 25–27, 2025 | **Playerchecker** — a short-lived player-list companion, presenting player names and server populations in a separate desktop window, with saved name filters and arrival sounds. An early attempt to turn player-list information into a useful external tool; development was discontinued at DM request. |
| December 8–9, 2025; later live-viewer work | **Logsagain** — reading the game's live log into a new, formatted window. The session viewer refreshes `nwClientLog1.txt` every two seconds, separates timestamps/speakers/messages, searches names and content, and groups Food/Water/Rest/Piety status lines. The earlier log-cleaner work also supplied noise filters, clipboard/export and a Windows portable v0.01 release. The wider parsing effort remained limited. |
| March 3 | **Memextractor** (folder `Memextrator`) — pulling strings out of the running game's memory so useful text could be copied and pasted elsewhere. CLI and local web tools searched UTF-8/UTF-16LE text and showed surrounding text/hex, with address exploration and saved scan results. It produced actual string matches but was abandoned quickly, before developing into a structured game-data reader. |
| July 5–6 | **ChatHijack** — an attempt to provide a chat-entry box outside the game and send its text through the original client's chat path. It barely worked: the experimental send path replaced the next real outgoing ASCII chat message within its existing length, rather than providing reliable independent chat entry. Electron/Frida plaintext and socket observation made it possible to inspect chat-bearing traffic along the way. |
| July 7–31 | **FullDecomp** — expanded into an Electron creature inspector and game overlays backed by Python/Frida readers and binary research. Added live HP/temporary-HP and status-effect overlays, minimap composition, creature/placeable inspection, SQLite capture history, chat/NUI/engine-traffic recording, and native menu position/scale/viewport adjustments. A separate C++ client scaffold reached handshake/login transport work, with world entry and gameplay explicitly unimplemented. This was the bridge from observing the original game to reconstructing a client. |

**EntireDecomp: from a model viewer to the current replacement client**


| --- | --- |
| August 1–2 — research foundation | Created this workspace and pinned the original executable/build. Traced object-to-mesh drawing, vertex buffers, shaders, scene buckets, window/context creation, camera dispatch and the frame-presentation chain. |
| August 3–9 — first independent renders | Built the Electron/Three.js ASCII MDL viewer, then added static binary MDL parsing. Original chest, obelisk and rock resources established working geometry, texture lookup and model hierarchy handling outside the game. |
| August 10–16 — creature foundation | Traced native skin rendering and displayed original skin nodes in static poses. This established the model/skin foundation; animated gameplay came later. |
| August 17–23 — original UI and module exploration | Catalogued the installed native GUI layouts, artwork, fonts and localized text. Added gameplay-panel presentation and Witch's Wake journal content while module/area loading, picking, movement and door interactions developed around the viewer. |
| August 24–September 6 — gameplay reconstruction | Expanded character import, object identity, rules/stat providers, script execution and authored interactions. Combat research separated attack/save/damage calculations from the still-incomplete action loop; the viewer was growing into a partial game runtime. |
| September 7–13 — animation and early combat | Connected broader animation and early combat behavior. Body/attachment playback, action scheduling and combat outcomes became active implementation work rather than static model previews. Full combat compatibility was still open. |
| September 14–20 — spell effects | Added spell-effect benchmarking and continued casting, projectile, particle and effect-lifetime work. Visual effects became both a compatibility task and a major performance workload. |
| September 21–24 — authenticated original-server login | Completed the encrypted handshake/login sequence against the unchanged local NWN server. This proved authenticated admission, with character selection, reliable sessions and world entry still separate milestones. |
| September 25–30 — multiplayer session foundation | Built application-session admission, character/resource handling and replicated-world integration. Subsequent work connected visible areas, movement, chat and server-authoritative actions to the replacement frontend. |
| October 1–10 — Electron frame-time investigation | Profiled dense scenes, shadows, lighting, hierarchy/matrix updates and particle work. Tested shader preparation, cache/lifetime changes and particle vertex workers. Some scoped improvements held, while live regressions and expensive complete scenes showed the frontend still had substantial frame-time problems. |
| October 11–13 — first native Godot room | Established the native desktop project and imported a captured room through a temporary GLB bridge. Godot rendered the captured geometry on Vulkan; frozen animation, effect/lighting differences and missing gameplay integration kept this an engine/import milestone. |
| October 14–17 — primary frontend migration | Recorded the move from JavaScript rendering to Godot because of frame-time issues. The Electron/Three.js frontend became the preserved comparison client while native rendering, input, animation and local-server integration became the main development path. |
| October 18–22 — native ownership and gameplay | Moved original-resource decoding, model/texture preparation and scene assembly into Godot, replacing whole-area conversion on the normal route. Expanded native HUD/windows, actions, inventory, spellbooks, NUI, character creation and server-confirmed progression. Protocol/services remained transitional JavaScript. |
| October 23 onward — original-client parity | Made actual base gameplay and mixed original/replacement-client interoperability the central acceptance target. Continued combat/casting, projectiles, equipment effects, movement, doors, travel, menus and cleanup checks against the unchanged original server. |
| October 24–26 — loading and streaming | Investigated original world-join methods, player-centered publication, worker/resource preparation, material prewarming and retirement hitches. Added recorded-area replay and stage timing to distinguish resource preparation from scene publication and rendering costs. |
| October 27–28 — player workflows and original-art UI | Expanded player/party controls, invitations/attitudes, barter, local character handling and model-based menu framing. Local multi-participant checks verified selected real server outcomes; full mixed-client and visual/input coverage remained open. |
| October 29–30 — resource and radial work | Advanced resource residency, compiled archive/table indexing and original class/domain/spell radial hierarchy research. Continued checking cache identity, server resource precedence, nested choices and stale-action rejection. |
| October 30–31 — particle and model processing | Expanded compiled particle simulation, storage/upload and experimental batching/pooling, alongside model controller/pose/hierarchy optimizations. Scoped image, arithmetic, lifetime and local-server checks supported individual changes; complete dense-scene performance remained unfinished. |
| October 31–November 1 — lighting comparison and continued parity work | Compared original and replacement rendering in the same room and developed an opt-in native lighting candidate. The user reported that the room looked similar; broader lighting/material/vision coverage, missing particle images, clean performance comparisons and remaining UI/gameplay work stayed open. |

Individual feature notes retain their actual test scope, failures and remaining
work. A parser test, offline replay or single successful server scenario does
not establish complete gameplay or performance parity.

The earlier efforts remained companion tools. Logsagain depended on what the
game wrote to its log; Memextractor found text without establishing stable
object layouts; ChatHijack's external input remained unreliable. FullDecomp
could inspect client-resident stats/classes/feats and placeable data, enrich
those reads with original resources, and adjust native menus, but its overlays
still depended on the original process and build-specific layouts. Its separate
client scaffold did not reach playable world entry.

The capabilities and recorded dates were checked against local source,
documentation, package metadata and retained artifact summaries. The
illustrative chronology deliberately uses different dates. This review does
not claim fresh execution or live validation of the retired tools, or that
every experiment was carried into the current client. Their source, binaries,
captures and private data remain outside this repository.

## What the current client can do

These paths have documented component checks and/or tests against an original
local server. Coverage varies by feature and content; the linked notes give the
boundaries.

| Area | Current capability |
| --- | --- |
| Connection and characters | Native server browser with Direct/Favorites/History and discovery; encrypted login; local/server character selection under server policy; export/save/reconnect. Native fifteen-page character creation includes active server-table rules, BIC writing, appearance preview and voice samples. [Creation](godot-client/NATIVE-CREATION.md), [browser](godot-client/NATIVE-SERVER-BROWSER.md). |
| Original content | Reads installed KEY/BIF, module/HAK and loose resources, Workshop content and admitted NWSync content. Native catalogs preserve resource precedence; workers prepare original models, textures, palettes, tables and text. Caches/residency and compiled metadata indexing reduce repeated work. [Resources](godot-client/NATIVE-RESOURCE-RESIDENCY-GOAL.md). |
| World and movement | Renders live replicated areas, terrain, objects and animated creatures with GPU skinning; handles spawn/removal and appearance changes. Supports click movement, keyboard drive prediction/collision, camera controls, picking, doors and area changes. Local reconnect and A–B–A transition checks exist. [Movement](godot-client/NATIVE-MOVEMENT.md), [transitions](godot-client/NATIVE-AREA-TRANSITIONS.md), [playability fixes](godot-client/NATIVE-PLAYABILITY-BUGFIXES.md). |
| Gameplay and combat | Submits original interaction, spell, feat, skill, item and queue-cancellation requests. Native radial menus, targeting, spell preparation and three-page quickbars are connected. Actual local checks cover melee/casting, bow/sling projectiles and selected parry, shield and blood effects. The original server decides outcomes. [Actions](godot-client/NATIVE-PLAYABILITY-ACTIONS.md), [combat](godot-client/NATIVE-COMBAT.md), [casting](godot-client/NATIVE-CAST-VISUALS.md). |
| Inventory and progression | Inventory/equipment, containers, merchant purchases/sales, item use, character records and server-confirmed level-up. Two-participant local checks also cover player barter. [Inventory](godot-client/NATIVE-INVENTORY.md), [level-up](godot-client/NATIVE-LEVEL-UP.md), [barter](godot-client/NATIVE-BARTER.md). |
| Communication and menus | Rich chat/history, dialogue/replies, examination, map/journal, status HUD, party controls and player invitations/attitudes. Original artwork, fonts, icons and model-based window framing are used across many menus. [Gameplay desktop](godot-client/NATIVE-GAMEPLAY-DESKTOP.md), [players](godot-client/NATIVE-PLAYERS-FRAME.md). |
| Server UI and travel | Native scripted NUI controls, bindings, images, popups and server callbacks have local checks. Server-requested cross-server handoffs have local character/content/recovery evidence, subject to endpoint policy and remaining route-specific integration. [NUI](godot-client/NATIVE-NUI.md), [handoffs](godot-client/NATIVE-HANDOFF-ENABLED.md). |
| Effects and audio | Native effect/model/particle paths, compiled particle simulation, sky and partial weather; original effect, script and creature-voice audio paths. Coverage and live acceptance vary. [Compiled particles](godot-client/NATIVE-COMPILED-PARTICLES.md), [world audio](godot-client/NATIVE-WORLD-AUDIO.md), [voices](godot-client/NATIVE-CREATURE-VOICES.md). |

## What it cannot yet promise compared with the original binary

- **Complete game or campaign replacement.** Multiplayer is the current focus.
  The earlier JavaScript client has partial offline rules, scripts and gameplay,
  but a complete native single-player campaign, VM/scheduler, save/load and
  offline simulation have not been migrated or accepted.
- **Full multiplayer interoperability.** Successful original-server sessions and
  local action tests exist, but broad paired original/replacement-client testing
  is still required. Every server/mod, custom class/item, party/control case,
  vault policy and cross-server failure/recovery path is not covered.
- **Every original gameplay and UI behavior.** Combat timing/blending, reactions,
  death, special attacks, targeting, nested radial choices, inventory/store edge
  cases and NUI styles/input still have open branches. Original art and working
  controls do not by themselves establish exact layout, gesture or state parity.
- **Rendering equivalence.** Original assets are retained, but lighting, shadows,
  vision, materials, weather and specialized effects remain incomplete. A current
  opt-in lighting candidate now has a same-room live comparison that the user
  reports looks similar to the original. Complete material/shadow/vision coverage
  and representative performance acceptance remain open; see
  [current lighting evidence](godot-client/NATIVE-LIGHTING-CORRECTION.md).
- **Complete or consistently cheap particles.** Supported effects run natively,
  but missing-resource cases, specialized emitters, transparency/order and dense
  effect workloads remain open. Some batching/pooling paths are experimental.
  Particles currently default off; enabling them is necessary when assessing
  full-effect behavior and performance.
- **Original-client loading speed or sustained 60 FPS.** Worker loading,
  prewarming, native indexing and compiled processing have measured improvements,
  but cold loads, publication/retirement hitches and dense animated scenes remain
  targets. Sparse scenes, isolated kernel timings and a fast offline capture do
  not establish complete-world frame-time parity.
- **Fully native services or release-level stability.** Node/Electron protocol and
  credential services remain. Historical native crashes/shutdown timeouts and
  pending-work lifetime cases remain documented; clean scoped runs do not close
  every retained failure.

The acceptance target is original behavior and mixed-client play on unchanged
servers, with original resources and server-authoritative outcomes. Engine
lighting differences are allowed, but cannot change gameplay visibility,
information, targeting or outcomes. See the
[base gameplay goal](godot-client/BASE-GAMEPLAY-GOAL.md) and
[migration checklist](godot-client/MIGRATION-GOAL.md).

## Running the active client

The supported development route is Windows/PowerShell with a compatible Node.js
installation (including `node:module.registerHooks`), npm, and MSVC x64/Windows
SDK build tools for the native helpers/extensions. The project pins its Godot
runtime in [runtime-lock.json](godot-client/runtime-lock.json); setup downloads
and verifies that runtime locally.

From the repository root:

```powershell
npm install
.\godot-client\tools\setup.ps1
.\godot-client\join-native.ps1
```

This opens the native frontend/server browser; choose a server and character.
The historical `join-arelith.ps1` name also opens this browser, rather than
automatically joining Arelith. A valid user-owned NWN:EE installation, required
server content and CD key are needed; proprietary assets and credentials are
not included.

For the owned local Prelude setup:

```powershell
.\godot-client\join-local.ps1
```

The local launcher expects the original install/server under
`../FullDecomp/NwnRootInstall`, starts its owned localhost profile on UDP 5121
when absent, and leaves that server running after the client exits. These are
development-workspace assumptions, not a standalone packaged distribution.
See [Godot documentation](godot-client/README.md) and the
[direct-entry ownership note](godot-client/NATIVE-SESSION-RENDER.md) for details;
older bridge/GLB milestone sections describe historical paths.

The preserved Electron/Three.js reference client can still be built and opened
with `npm start`. It is no longer the primary frontend. `npm test` runs the
JavaScript regression suite; native Godot, GPU and original-server checks have
separate feature-specific harnesses and are not covered by that command alone.

## Research baseline and documentation

The objective is a behavioral reconstruction backed by code paths and runtime
evidence. Decompilation cannot recover all original names, types, comments or
source-level distinctions.

- Original target: `../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`
- Target build: NWN:EE `89.8193.37-17`, x64 PE
- Expected SHA-256: `3B7CB1252E0EDB2CE22D7971F333AADE027039AE30A45B4BC64732C3E6BEC73A`
- Existing Ghidra project: `../FullDecomp/ghidra-projects/NWN-EE-8193.37-17.gpr`
- Existing setup notes: `../FullDecomp/GHIDRA_MCP_SETUP.md`

Keep the original binaries and shared analysis inputs unchanged. Record target
identity, addresses and validation scope, distinguish **Observed**, **Inferred**
and **Open** findings, and verify behavior through independent paths or runtime
observations. Keep proprietary assets, private captures, credentials and runtime
logs out of source control.

Useful entry points:

- [Research tracker](RESEARCH_TRACKER.md) and [binary inventory](evidence/binary-inventory.md)
- [First object render](evidence/first-object-render.md) and [original render pipeline](evidence/rendering-pipeline.md)
- [Godot migration](godot-client/MIGRATION-GOAL.md) and [base gameplay acceptance](godot-client/BASE-GAMEPLAY-GOAL.md)
- [Loading optimization](godot-client/NATIVE-LOADING-OPTIMIZATION-GOAL.md) and [resource residency](godot-client/NATIVE-RESOURCE-RESIDENCY-GOAL.md)
- [Particle performance work](godot-client/NATIVE-PARTICLE-IMPACT-PERFORMANCE.md)
- [Static research wiki: build and publishing](wiki/README.md)

Many feature notes are chronological evidence logs. Read their latest scoped
updates alongside the active goals; an older “pending” list or historical pass
does not override newer implementation evidence or establish full acceptance.
