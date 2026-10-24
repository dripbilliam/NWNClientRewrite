# Native NWN client prototype

The playability baseline is now the **original Prelude campaign** on the owned
local server at `127.0.0.1:5121`. See [local campaign acceptance](LOCAL-PLAYABILITY.md).
Scripted fixture modules and offline captures support focused checks; campaign
playability requires the actual live campaign, including animated characters,
movement, interactions and area transitions.

[Native creature appearance and PLT textures](NATIVE-CREATURE-ASSETS.md) now
prepare from original resources, with original body-part geometry drawing and
independent character colors verified. Complete actor animation/assembly and
direct native campaign integration remain next.

The [direct native captured world](NATIVE-WORLD-STATIC.md) now assembles all 48
terrain tiles and 889 static object entries with area/model lighting. Run
`./godot-client/native-world.ps1` for its offline inspection view. Creatures,
effects and gameplay integration remain incomplete; this is not the server client.

Current priority is [complete native world rendering](NATIVE-CAPTURED-ASSETS.md).
Original captured assets and ASCII/binary models now render directly through
native loading. Full-world assembly is next; further performance experiments
are deferred. The multiplayer launchers still use the transitional JS path.

A separate [native original-resource preview](NATIVE-DIRECT-RENDER.md) now runs
with `./godot-client/native-model.ps1`, without JS/Electron or scene conversion.
This static-model entry is an intermediate step; the multiplayer path below
still needs native area and animated-content preparation.

[Native terrain streaming](NATIVE-TERRAIN.md) also has a separate direct entry,
`./godot-client/native-area.ps1`. Experimental batching helps warm construction
but has not shown a steady-rendering improvement. Complete captured-world
playability and frame pacing are the performance priority.

The current migration target is a **fully native Godot runtime**, including
resource loading, area construction and networking. Native file-backed archive,
GFF/2DA and static binary-model readers plus native worker decoding are now
implemented and tested; see [NATIVE-OWNERSHIP.md](NATIVE-OWNERSHIP.md).
The launchers below still use the transitional JS backend/whole-area GLB path
until its replacements pass integration checks. Full migration is incomplete.

This is the new top-level native Godot project. The existing Electron client is
preserved. The native prototype can now join the owned local server. To open
the public server browser and select your own server, run
`.\godot-client\join-arelith.ps1`. This opt-in launcher allows direct addresses,
history, favorites and Internet discovery without automatically connecting or
selecting a character. It reuses the persistent content cache and installed
NWSync databases read-only. Server-requested transfers are now enabled within
the session's address policy, with owned-local character/NUI/NWSync/recovery
checks. See [NATIVE-HANDOFF-ENABLED.md](NATIVE-HANDOFF-ENABLED.md). Public-server
acceptance and the full migration remain incomplete.
The local test launcher retains its localhost-only default.

Original-model dawn/day/dusk/night skies are now presented in a separate native
camera-centered pass, with local transition and offline rendering checks. See
[NATIVE-SKY.md](NATIVE-SKY.md). The original horizon/material follow-up and
explicit world/UI retirement before quit are locally verified. See
[NATIVE-HORIZON.md](NATIVE-HORIZON.md) and [NATIVE-SHUTDOWN.md](NATIVE-SHUTDOWN.md).
The exact former C++ shutdown fault remains unproven. Weather is still incomplete.
Original rain/snow models, native fades and six-instance particle ownership
now render through owned-local area transitions. This is work in progress:
one native runtime crash remains unexplained, and lightning/audio/timer
coverage is incomplete. See [NATIVE-WEATHER-RENDER.md](NATIVE-WEATHER-RENDER.md).
Particle materials now persist across buffer growth, with cold-compile,
allocation/lifetime and GPU readback checks. The previous crash is still
unresolved: [NATIVE-PARTICLE-MATERIALS.md](NATIVE-PARTICLE-MATERIALS.md).

The full migration is an active goal, with multiplayer first. Its feature
checklist and evidence requirements are in [MIGRATION-GOAL.md](MIGRATION-GOAL.md).

The pinned Windows runtime is Godot 4.7.2, using desktop Forward+ with Vulkan.
Run `./tools/setup.ps1` from this directory to fetch the official archive and
verify its published SHA-256 before extracting the engine. No installer or
system-wide setting changes are needed.

Game assets stay in their existing installation/capture folders or an external
temporary runtime bundle. Do not copy proprietary NWN assets into this project.
The initial loader accepts an external glTF room and captured camera. That is
an import/engine milestone, not proof of NWN visual or gameplay parity. Native
materials, lighting/fog/keyhole, animation, particles, input, UI and network
integration require explicit validation before a migration or 60 FPS claim.

The engine owns the loaded scene and frame loop. Electron is not hosting a
Godot web export. The established JavaScript resource/network work can be reused
as a transition bridge without retaining Three's per-frame scene traversal.

The first captured-room import has run on native Vulkan. See [STATUS.md](STATUS.md)
for measured results and the remaining fidelity gaps, and [MIGRATION.md](MIGRATION.md)
for acceptance requirements. Launch the prototype with:

```powershell
.\godot-client\run.ps1
```

This uses the latest registered external capture. Native camera controls,
picking/highlighting and movable inspection menus are now available; see
[SYSTEMS.md](SYSTEMS.md) for controls, validation and remaining migration work.
To select a different external bundle or record a bounded diagnostic:

```powershell
./run.ps1 -Scene 'C:\path\outside-project\room.glb' -Frames 600 -Report 'C:\new-report.json'
```

The external GLB needs the bridge's matching `room.json` manifest. Reports must
use unused paths. Omitting `-Frames` leaves the offline prototype open.

To join the actual local NWN server instead:

```powershell
.\godot-client\join-local.ps1
```

This starts the owned Prelude server if needed and opens Godot's multiplayer
menu. Connect to `127.0.0.1:5121` with the existing protected CD key, choose an
installed/saved character or an advertised server character, and click Play.
Godot loads that server's actual area. Click ground to move; W/S move forward
and back, A/D turn, Q/E strafe, and Shift walks. Click objects to interact, and press Enter
to chat. Right click / I requests server examination. Middle drag orbits the camera. The Multiplayer menu provides export
and disconnect/reconnect; saving on disconnect/window close defaults on.
See [LOCAL-MULTIPLAYER.md](LOCAL-MULTIPLAYER.md) for validation and limits.
Live object transforms, native rigid/skeletal model playback, chat and basic
conversations are connected. See [NATIVE-MODELS.md](NATIVE-MODELS.md) for animation
validation and limits. Live spawn, removal and shape/clothing replacement now
pass real local-server checks; see [NATIVE-WORLD-LIFECYCLE.md](NATIVE-WORLD-LIFECYCLE.md).
Particles, broader equipment/mount coverage, combat animation queues, NUI and
the full gameplay menus still need migration. The transitional bridge adds
loading work; it has not established performance parity.

Area changes now pass a real local A–B–A check with an old model job pending,
plus saved-character reconnect and native owner cleanup; see
[NATIVE-AREA-TRANSITIONS.md](NATIVE-AREA-TRANSITIONS.md). The project editor can
stay open for functional checks. The owned server is left running on Prelude.

Native drive prediction, original input packets, collision/path repair and gait
now pass retained original-client observations and real local checks. See
[NATIVE-MOVEMENT.md](NATIVE-MOVEMENT.md) for controls, evidence and remaining limits.

Native colored speech/system history, dialogue/reply/end/abort, examination and
portraits, server tokens and script overhead prompts now pass real local tests;
see [NATIVE-GAMEPLAY-TEXT.md](NATIVE-GAMEPLAY-TEXT.md). The FPS counter is visible
immediately and F3 toggles it. `join-local.ps1 -AutoPlay` enters the local server
with the installed wizard and leaves the preview open.

Right click now opens a native context-action wheel with original icons, deeper
spell/feat pages, independent use counters and typed targeting. Actual local
Examine/Talk/dialogue and a server-consumed Light spell pass 25 checks. See
[NATIVE-ACTIONS.md](NATIVE-ACTIONS.md) for evidence and remaining limitations.
This does not complete combat cues, AoE drawing, player windows or NUI.

The native **B** spellbook now shows known/prepared spells, metamagic,
descriptions and selectable spell-family variants. Drag a child onto the native
three-page quickbar; F1–F12 casts through the existing targeter. Actual local
family casting and clear/re-prepare pass 49 checks. See
[NATIVE-SPELLBOOK.md](NATIVE-SPELLBOOK.md). Live debug shortcuts now use
Ctrl+Alt+F1/F2/F3, leaving function keys for the quickbar.

Native combat queues, timed cast/attack clips and original hit-event playback
now pass actual local tests with moving body/robe clocks and GPU skin changes.
See [NATIVE-COMBAT.md](NATIVE-COMBAT.md). Projectiles, particles/impact effects,
audio and full combat/performance acceptance remain incomplete.

References: [Godot renderers](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html),
[runtime loading](https://docs.godotengine.org/en/stable/tutorials/io/runtime_file_loading_and_saving.html),
[GLTFDocument](https://docs.godotengine.org/en/stable/classes/class_gltfdocument.html).

Native server NUI now has a verified local foundation: 21 control kinds, eight draw primitives, original fonts/artwork, watched typed bindings and canonical indexed arrays, nested resource-backed menus, complete toolbar height, simultaneous movement/camera input and A–B–A lifetime checks. See [NATIVE-NUI.md](NATIVE-NUI.md) for actual server checks, retained failures and remaining full-parity requirements. Text themes now publish one native notification per update. Gameplay popups remain embedded while diagnostics alone uses an OS window; the corrected cross-feature regression passes57 +59 local NUI and25 Windows settings checks. The user has deferred the retained emoji/native-engine issue; its diagnostic build is stopped and production text/runtime are unchanged.

NUI action completion also passes locally: two native server-target callbacks and a toolbar-triggered normal Light cast with actual prepared-use consumption (2 to 1), alongside the 16 dialogue +39 NUI checks and A–B–A cleanup. See [NATIVE-NUI.md](NATIVE-NUI.md); full styles, reconnect stress, other action types and performance remain pending.

NUI also passes a real saved-character reconnect: 39 +41 native checks across two sessions and six rendered area admissions, old window/font/image retirement and stale old-connection input rejection. See [NATIVE-NUI.md](NATIVE-NUI.md). Pending-resource races, full style/action breadth and moving-scene performance remain incomplete.

The installed NUI skin adapter passes 49 +51 actual local checks across saved-character reconnect, including original checkbox/radio, slider/progress, scrollbar, combo, editor and window-button artwork. Cached styles retire with the connection. Nineteen authored skin checks, fifteen native UI regressions and 52 Node checks pass. See [NATIVE-NUI.md](NATIVE-NUI.md); full state/pixel parity, popup behavior, pending-work races and performance remain incomplete.

Native embedded NUI popup input now passes 57 +59 actual local checks across reconnect: GUI opening, keyboard dropdown selection, typed color entry, complete popup pointer bounds and prior casting/movement/lifetime checks. A late localized projection can no longer repopulate a retired image queue. Sixteen native popup, eight authored pending-fragment, fifteen UI, nineteen skin and 54 Node checks pass. See [NATIVE-NUI.md](NATIVE-NUI.md); forced pending-work live reconnect, broader popup/state parity and performance remain pending.

NUI large JSON now crosses bounded, ordered, hash-checked fragments without raising the ordinary bridge cap. Authored native/JS round trips pass, and the existing 57 +59 local NUI regression still passes. This does not accept giant visible-widget layout: a million-character label/edit stress attempt remains a recorded performance failure. UI is the current priority, followed by rendering and combat; see [MIGRATION-GOAL.md](MIGRATION-GOAL.md).

The native buff/status bar now passes 17 +18 actual local checks over saved-character reconnect, including original icons/localized labels, server-driven expiry, MMB/WASD/outside-click movement, six animated area admissions and clean ownership retirement. Seventeen authored GUI checks and 66 Node regressions pass. See [NATIVE-STATUS-HUD.md](NATIVE-STATUS-HUD.md). Native settings/workshop/debug UI and broader status/fidelity/performance coverage remain. UI remains first, then rendering and combat.

Native party portraits, server-disclosed HP and the eight original HUD controls now pass 28 +29 local checks across saved-character reconnect and six animated admissions. Actual companion membership, portrait spell targeting, radial examination, Rest and simultaneous-menu movement are verified; the player-attitude window uses canonical private handles. Eighteen authored native GUI checks and61 Node regressions pass. See [NATIVE-PARTY-HUD.md](NATIVE-PARTY-HUD.md). Actual second-player attitude exchange, broader associates/fidelity, creation and remaining native settings/workshop/debug UI remain pending.

Native Main Menu settings now expose the Workshop root/per-mod global HAK toggles and existing Windows-protected CD-key store. The admitted world has a compact optional FPS counter; debug information opens in a separate five-tab native OS window. Twenty-five isolated Windows UI/store checks,34 +35 actual local reconnect/transition checks,20 authored GUI checks and119 Node regressions pass. See [NATIVE-FRONTEND-SETTINGS.md](NATIVE-FRONTEND-SETTINGS.md). Server browser, remaining creator preview/audio/fidelity and preferences, audio, interactive debug/fidelity and other UI remain pending before rendering/combat acceptance.

The native multiplayer lobby now has a fifteen-page Create character flow, original portraits and palettes, package recommendations and shared typed first-level submission. See [NATIVE-CREATION.md](NATIVE-CREATION.md) for actual local vault-policy tests and remaining preview/voice/fidelity limits. UI remains the current priority, followed by rendering and combat.

Native server browser now has locally verified Direct/Favorites/History, masked transient login fields, actual server query, atomic safe-metadata persistence and pending-login cancellation. The local regression passes 40 checks across native creation and two animated admissions;22 browser GUI,20 lobby,16 creator GUI and119 backend regression checks pass. See [NATIVE-SERVER-BROWSER.md](NATIVE-SERVER-BROWSER.md). Only localhost 5121 is enabled; public discovery/login/handoffs and broader UI/fidelity/audio remain open. The complete migration/performance goal remains active.

Native creation voice sampling now reuses original SSF cycling and resources with Godot-owned output, fixed-footer controls and selected-voice feedback. Actual WASAPI playback, native clock/checksum, soundset export and two animated admissions pass48 local checks;19 native audio,16/22/20 creator/browser/lobby GUI and135 backend regressions pass. See [NATIVE-AUDIO.md](NATIVE-AUDIO.md). Original-model appearance preview and broader UI/audio remain open before rendering/combat acceptance; migration/performance stay active and only localhost is enabled.

Native original-model appearance preview now has local evidence for head/clothing/palette changes, animated body parts, rotation/zoom, canonical export and two moving admissions:61 checks. Nineteen rendered and18 headless preview checks,16/19/22/20 creator/audio/browser/lobby GUI regressions and164 backend tests pass. Four GLB geometry/texture hashes are unchanged while idle-only metadata cuts transfer size about86%. See [NATIVE-CREATION-PREVIEW.md](NATIVE-CREATION-PREVIEW.md). Broader content/help/font/device fidelity and full UI/rendering/combat/moving-scene60FPS remain open.

Owned inventory items can now be dragged onto all three native quickbar pages, with original item icons and actual local-server equipment activation. See [NATIVE-INVENTORY.md](NATIVE-INVENTORY.md#inventory-item-shortcuts): 20 local, 12 rendered synthetic drag, 24 inventory, 22 spellbook and 40 backend checks pass. Broader property menus and full UI/rendering/combat/performance parity remain incomplete.

Right-click a native quickbar slot for [assignment menus](NATIVE-SHORTCUT-MENUS.md):
original item/spell/feat/skill/ability/command choices, nested families, paged
lists and Clear. The latest local regression passes 34 checks, including actual
Light/potion consumption and original command submission. Broader action and
reconnect/fidelity coverage remain pending; the migration goal stays active.

Native [skill shortcuts](NATIVE-SKILLS.md) now send the original skill protocol,
including targeted selection, Parry mode and immediate self-targeted crafting.
The combined local regression passes 45 checks and opens the real server's
crafting conversation; 75 backend tests and native GUI/input regressions pass.
Broader skill outcomes, full UI/rendering/combat and performance remain open.

[Saved shortcut reconnect](NATIVE-SHORTCUT-PERSISTENCE.md) now passes 21 +15
native checks: seven bindings across three pages, actual exported/read-back
records, a changed potion object ID, native Ctrl+F activation and resource
retirement. The regression includes 100 backend tests. Broader custom/charged/
paired shortcuts and full migration/performance acceptance remain open.

Options → Game now has persistent [combat feedback controls](NATIVE-FEEDBACK-OPTIONS.md).
Floating damage/special attack text can be disabled while history and server
prompts remain visible; damage can display grouped values or a total. Twenty
actual local checks, 10 new GUI checks, 21 settings GUI regressions and 122 backend
tests pass. Broader graphics/audio Options and full migration remain open.

Native [camera modes](NATIVE-CAMERA-MODES.md) now provide persistent Top-down,
Chase and Stiff chase selection, original follow/input calculations and manual
view preservation through area changes. The current local regression passes
23 camera checks across three animated admissions; 24 native GUI and 139
backend checks pass. Scripted camera commands, collision/clear-view behavior
and full migration/performance acceptance remain open.

[NWSync admission](NATIVE-NWSYNC.md) now has native progress/cancel/failure
controls and verified resource mounting. Actual local tests cover cancellation,
cold downloads, zero-request cached login and one-blob cache repair, followed by
three animated admissions and a rendered downloaded texture. Twelve new GUI,
20 existing lobby and 187 backend checks pass. Public login/handoffs and complete
migration/performance acceptance remain open; the launcher stays local-only.

[Native location effects](NATIVE-POINT-EFFECTS.md) now consume actual local
server area-effect packets with original model selection, animation, particles
and retirement. Two frozen local runs pass60 visual checks; native phase/fade
ports match30,288 original-state/call comparisons. Separate authored probes
verify cached original invisible dummy hosts, anchors, expiry and shutdown.
Audio, specialized effects/projectiles, full world timer and complete
multiplayer/performance acceptance remain open. No public connections occurred.

[World audio](NATIVE-WORLD-AUDIO.md) now plays original effect phase and server
script sounds through Godot, with native listener/range/source rules and bounded
resource ownership. Stereo and WASAPI mixer tests pass40 checks each; actual
playback references now participate in quit retirement. A repeated local run
still exposed a native shutdown AV, so broader audio and stable shutdown
acceptance remain open and the migration goal stays active.
