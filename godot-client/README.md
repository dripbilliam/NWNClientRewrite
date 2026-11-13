# Native NWN client prototype

The normal multiplayer launchers now use the **direct native Godot renderer**.
Normal startup opens **Main Menu**. Choose **Multiplayer** there to open the
server-selection flow; launching the program does not start a server connection.

Normal launches now keep the previously validated lighting and shared particles
together in the [gameplay rendering profile](NATIVE-RENDER-LAUNCH-PROFILE.md).
Run `.\godot-client\join-native.ps1`; `-SharedParticles` remains compatible.
`-RenderProfile legacy` is the explicit older-rendering diagnostic rollback.
[Responsiveness correction and diagnostics](NATIVE-UI-RESPONSIVENESS-REGRESSION.md)
also removes blocking native loopback writes and instruments record selection.
The [original character picker](NATIVE-CHARACTER-FRONTEND.md) prepares alongside
Main Menu. Server data updates that stable pregame screen; it does not rebuild
the frame from gameplay resources after the roster arrives.

**Main Menu → Options → Prework** provides explicit **Prepare assets**,
**Cancel preparation**, and **Clear saved prework** actions. Saved model bundles
and artwork from opened UI panels can be reused across sessions. Choose installed
or downloaded server content directly from the menu, without joining first.
Current-session appearances and all-model preparation are separate scopes.
Preparation supports Automatic or 1/2/4/8 workers, live progress/rate updates,
and **View saved files** to open the generated cache directory.
Its background process keeps preparation failures from closing the game client.
See [persistent asset prework](NATIVE-ASSET-PREWORK.md) for scope and
invalidation details.

The active priority is [complete native UI parity](NATIVE-UI-PARITY-GOAL.md):
original-game screens must match their appearance and actions; unique screens
must follow the base game's style. General porting resumes only after the full
UI audit passes. [Earlier UI/combat work](NATIVE-UI-COMBAT-MIGRATION-GOAL.md)
remains unfinished backlog and scoped evidence.
[Animated GUI mesh sampling](NATIVE-GUI-ACTOR-SAMPLER.md) now applies original
texture clamp/filter metadata to animated controls as well as static panels,
removing repeated character-chooser tab borders. Full UI parity remains open.
[Native local character metadata](NATIVE-LOCAL-CHARACTER-CATALOG.md) now supplies
BIC names, classes and portraits and uses the active Pregen table for filtering.
The installed corpus and owned-local actions pass scoped checks.
[Profile and enabled Workshop vault discovery](NATIVE-LOCAL-VAULT-DISCOVERY.md)
now follows original alias precedence. Delete/Customize and full catalog parity
remain open.
[Pregenerated-character preferences](NATIVE-CHARACTER-PREGENERATED.md) now
persist natively across chooser instances, with original lifecycle/input and
owned-local checks. Complete local metadata, filtering availability and local
Delete/Customize parity remain unfinished.
[Focused chooser edit keys](NATIVE-CHARACTER-CHOOSER-EDIT.md) now stay owned
like the original hidden control, preserving cursor selection without inventing
Enter/Escape/Tab actions. Graphical input and owned-local server checks pass.
[Automatic chooser selection](NATIVE-CHARACTER-AUTO-SELECTION.md) now follows
the original first-row rebuild policy, with exact BIC ownership in diagnostics.
Graphical input and fresh owned-local actions pass; full UI parity stays open.
[Chooser cursor keys and titles](NATIVE-CHARACTER-CHOOSER-KEYS.md) now follow
original row navigation/scroll rules and localized record captions. Their
graphical/local follow-up is included in automatic chooser selection above.
[Pregame Character statistics](NATIVE-PREGAME-CHARACTER-NUMBERS.md) now follow
original numeric display rules and typed BIC fields. Headless checks pass;
the [detail-list follow-up](NATIVE-PREGAME-CHARACTER-DETAILS.md) also connects
original generated rows and scroll ownership. Fresh visual/local validation and
the complete Character/UI audit remain open.
[Native player window and invitation](NATIVE-PLAYERS-FRAME.md) now use original
resources and working selection/Tell/attitude/party controls, with real two-peer
local-server checks. Administrator and full original-client/state/role parity
remain open.
[Native conversations](NATIVE-CONVERSATION-FRAME.md) now use original panel
geometry, speaker portraits, fonts, content sizing and separate scrollbars,
with original-binary policy comparisons and real local-server reply/end/abort
checks. Full conversation variants and the complete UI audit remain open.
[Native journal](NATIVE-JOURNAL-FRAME.md) now uses original pages, expandable
quest rows, sorting, timestamps, scrollbars and saved editable personal notes.
Actual local-server quest lifecycle and simultaneous-window composition pass
scoped checks. Full role/world-journal and original-client comparison remain open.
[Native area map](NATIVE-AREA-MAP-FRAME.md) now uses generated original frames,
source zoom/pan controls and the original pin editor. Native input and actual
local-server pin events and stored note lifecycle pass scoped checks; complete
original-client visual/role/gesture comparison remains open.
[Radial artwork and actions](NATIVE-RADIAL-UI.md), [target facing](NATIVE-TARGET-FACING.md)
and [movement-cue playback](NATIVE-MOVEMENT-CUE-PLAYBACK.md) document current
scoped fixes, original-binary evidence, local acceptance and remaining gaps.
[Feat families and Special Attacks](NATIVE-FEAT-RADIAL.md) covers native variant
shortcut packing, mode/availability rules and an authoritative local shape test.
[Private hit-effect defaults](NATIVE-BLOOD-VISUALS.md#private-constructor-hp-follow-up)
cover undisclosed NPC HP without changing authoritative health data.
[Original inventory equipment](NATIVE-INVENTORY-EQUIPMENT.md) now uses native
GUI positions, box meshes, empty-slot icons and item attachment points.
[Original bitmap fonts](NATIVE-BITMAP-FONTS.md) bind caption metrics and atlas
resources to the framed menus; full font and UI parity remain open.
[Original item Examine content](NATIVE-EXAMINE-CONTENT.md) restores source stat
blocks, localized inline fields and server-owned armor-category presentation.
[Original scroll input](NATIVE-SCROLL-INPUT.md) adds held arrows/rail paging,
font-relative wheel steps and focus-loss drag cancellation to shared frames.
[Content-sized scrollbar thumbs](NATIVE-SCROLL-THUMB.md) use original range
arithmetic/animated geometry; row lists scroll by their native linked height.
[Original UI resource inventory](NATIVE-UI-RESOURCE-INVENTORY.md) enumerates
shipped GUI controls and tracks programmatic surfaces separately.
[Original character-sheet frame](NATIVE-CHARACTER-FRAME.md) adds native page/tab
artwork, source-sized rows/fonts and the received-state Level Up control;
full record content, resizing and state parity remain open.
[Character-sheet resizing](NATIVE-CHARACTER-RESIZE.md) now uses its original
footer with retained size and coalesced original scrollbar geometry; exact
original limits/states and the full UI audit remain open.
[Original quickbar framing](NATIVE-QUICKBAR-FRAME.md) replaces stretched generic
slots with native model hooks/poses, original font/count placement and bottom
anchoring while preserving typed actions; full HUD/state parity remains open.
[Original party HUD framing](NATIVE-PARTY-FRAME.md) restores native portrait,
action, vertical-health/member and level-overlay geometry, with fixed self HUD
and separate roster scrolling; remaining indicators/roles/states stay open.
[Original health variants](NATIVE-PARTY-HEALTH.md) now follow received poison/
disease flags and original clip/timing rules; full HUD acceptance remains open.
[Spellbook layout research](NATIVE-SPELLBOOK-RESEARCH.md) recovers both original
windows and nine-column memorization rows. The [native spellbook frame](NATIVE-SPELLBOOK-FRAME.md)
now connects them, independently expandable groups and original help artwork to
typed actions; exact gestures/states and full original-client comparison remain open.
[Prepared-slot transfers](NATIVE-SPELL-PREPARATION.md) now preserve original
move/exchange ordering and wait for received server updates, with stale/pending
ownership and used icon alpha checked. Full spellbook/UI parity stays open.
[Inventory and container frames](NATIVE-INVENTORY-FRAME.md) add original panel
artwork,33px repositories, pages and per-pose button proportions without stretching.
[Native gold controls](NATIVE-INVENTORY-GOLD.md) add the original amount dialog,
gold dragging, server-owned ground/container transfers and native barter refusals.
[Native player barter](NATIVE-BARTER.md) adds original trade artwork and controls,
with owned-server item/gold exchange and cancellation refunds in both roles.
Mixed-client and wider trade edge cases remain open.
[Native merchant framing](NATIVE-STORE-FRAME.md) adds original linked category
tabs, the 33-pixel stock grid and localized buy/sell confirmation artwork, with
real owned-server transactions. [Examine and Identify](NATIVE-EXAMINE.md) now use
original frames with authoritative paid/free identification; body formatting,
scrollbars, fonts and full visual/context parity remain partial.
[Original scrollbar artwork](NATIVE-SCROLLBAR.md) now drives Examine and the
merchant confirmation, including their animated vertex/UV centers; full widget
repeat/step/font parity remains open.

Launches prefer a secondary monitor and do not activate the game window or its
console. Click the game window when ready to activate it. Automated checks retain
the non-activating window flag throughout. A single-monitor setup uses its
available screen.

Area changes use a [native loading screen](NATIVE-LOADING-SCREEN.md) until the
base tiles, complete player model and follow camera are ready. Press
**Ctrl+Shift+L** to reveal the unfinished world early for the current transition;
unrelated scenery continues streaming after normal reveal.

[Native keyboard prediction](NATIVE-DRIVE-PREDICTION.md) keeps W/S movement and
Q/E strafing continuous using server speeds and original collision resources;
A/D turn and Shift walks. Prediction and rendering run in Godot.
Run `./godot-client/join-arelith.ps1` to choose a server and character, or
`./godot-client/join-local.ps1` for the owned local server. JavaScript remains
in protocol/download services, while Godot reads and prepares render assets.
The former scene-staging route is an explicit fallback. See
[current native entry, evidence and remaining gaps](NATIVE-SESSION-RENDER.md).
The [native gameplay desktop](NATIVE-GAMEPLAY-DESKTOP.md) now connects the main
in-game menus, party HUD, quickbar and radial actions using original assets/fonts.
The [native action and NUI milestone](NATIVE-PLAYABILITY-ACTIONS.md) verifies real
localhost equipment, casting, purchases, advancement, combat cancellation and
scripted menus. [Direct-native character creation](NATIVE-CREATION.md) now includes
active server tables, original appearance/voice and original Prelude admission.
Full UI parity, broader creator/content coverage, advanced effects and
public-server transfers remain incomplete.
Native Workshop/override/portrait discovery and emitter resource decoding now
have [local evidence](NATIVE-LOCAL-CONTENT-EMITTER-DATA.md). Native particle
simulation, standard quad drawing and actor-channel playback now have
[scoped original-data and GPU checks](NATIVE-PARTICLE-RUNTIME.md); full effects
and moving-world performance remain incomplete.

The latest [native hot-path work](NATIVE-HOTPATH-OWNERS.md) adds persistent C++
particle/controller state, direct GPU streams, native pose/frustum checks,
incremental diagnostics and changed-object bridge updates. Offline room frame
times improve, but 60 FPS and full native networking remain incomplete.

[Impact and Heal particle collision work](NATIVE-PARTICLE-IMPACT-PERFORMANCE.md)
adds conservative tile lookup, native original-face/model-Part queries and
persistent bouncing-particle state. Local Heal animation frame-time p95 falls
from roughly15ms to8ms with the original particle assets/counts retained;
broader-room performance and full particle parity remain incomplete.

The [native interaction registry](NATIVE-INTERACTION-REGISTRY.md) now excludes
non-interactive scenery from picking/highlight bookkeeping while retaining its
rendering, effects and authoritative world state. Eligibility changes update
without a model reload; original hidden portal hit triangles remain pickable.

[Graphics settings and fuller profiling](NATIVE-GRAPHICS-PROFILING.md) are available
under **Main Menu → Options** in the native client. Particle simulation/drawing
defaults off, can be toggled immediately, and the preference is saved. The Performance tab
controls detailed timings, including unattributed frame time and profiling costs.

The playability baseline is now the **original Prelude campaign** on the owned
local server at `127.0.0.1:5121`. See [local campaign acceptance](LOCAL-PLAYABILITY.md).
Scripted fixture modules and offline captures support focused checks; campaign
playability requires the actual live campaign, including animated characters,
movement, interactions and area transitions.

The latest **direct native local gameplay** check passes movement, camera
follow, NPC examine/chat/dialogue replies and a real server-owned door transfer
from the Prelude bedroom to the 100-tile training area. NUI is deferred while
essential gameplay is completed. `./godot-client/play-native-local.ps1` opens
an experimental interactive version of that path with the installed wizard
test character. Native inventory/equipment and original item icons now pass a
server-owned unequip/re-equip and area-reopen check. Item abilities/stores,
spells/combat and other systems are still incomplete.
See [the current local milestone and limits](LOCAL-PLAYABILITY.md#native-local-gameplay-milestone).
The earlier milestone descriptions below remain historical; no full native
binary parity or performance acceptance is claimed.

[Native creature assembly](NATIVE-CREATURE-ASSETS.md) now includes original
binary/ASCII skins, inherited animation, equipment and ground items. The
captured room renders 48 tiles, 889 static objects, eight creatures and one
ground item directly. Effects and broader visual behavior remain incomplete.

The first **live direct-native Prelude** check also passes: nine tiles, twenty
entities and a 1.5-metre authoritative player walk, using original assets read
by Godot. Its protocol-only Node process rejects Three/Electron/render-staging
imports. `tools/test-native-local-world.ps1` is a bounded local functional test,
not the normal game launcher. Original tile lighting and native picking are
now restored in the local test. Native movement simulation is connected and
headless-tested, including original WOK height/cache loading across all five
Prelude areas; its live check, gameplay UI/effects, visibility, transitions
and full campaign playability remain pending. See [current evidence](NATIVE-LIVE-RENDER.md) and
[the acceptance route](LOCAL-PLAYABILITY.md). No FPS acceptance is claimed.

The direct entry also has a native raw-protocol chat/conversation/creature
examine path, including original TLK text, rule tables, color tokens and
portrait textures. Original fonts and NUI skin/image resources also load and
bind natively, with cold/warm reuse verified. Full item/token providers,
NUI layout/input, original GUI model skins, other menus and live validation
remain incomplete.

The [direct native captured world](NATIVE-WORLD-STATIC.md) now assembles all 48
terrain tiles and 889 static object entries with area/model lighting. Run
`./godot-client/native-world.ps1` for its offline inspection view. Effects and
gameplay integration remain incomplete; this is not the server client.

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

Ordinary [overhead speech](NATIVE-OVERHEAD-SPEECH.md) now uses the original
popup/font/timer and shared nameplate behavior, with source/context lifetimes.
[Server-script floating text](NATIVE-SCRIPT-FLOATING.md) has a separate native
queue and widget lifetime, model-independent pose anchoring and optional chat
echo; it no longer uses the legacy combat-digit widget.
The missing [area-border scenery](NATIVE-AREA-BORDER.md) now uses the original
`<tileset>_Edge.2da` rules and models through optional native streaming after
player admission. Original-data and isolated native functional checks pass;
live visual acceptance for these additions remains pending. These checkpoints
do not complete the broader UI/gameplay migration.

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
Equipped-weapon blur and scoped attack colours now have native integration and
headless original-data/model lifecycle checks. Live visual acceptance is queued:
[NATIVE-EQUIPPED-ATTACK-VISUALS.md](NATIVE-EQUIPPED-ATTACK-VISUALS.md).
Native special initialization and level20 eye effects now have original-code and
headless model/lifetime checks. Actual server/pixel acceptance remains queued:
[NATIVE-SPECIAL-INITIALIZATION.md](NATIVE-SPECIAL-INITIALIZATION.md).
Native combat barks/server26/1 voices now use native SSF/BMU decoding and actor
source ownership. Headless original-voice/retirement checks pass; actual server
and device acceptance is queued: [NATIVE-CREATURE-VOICES.md](NATIVE-CREATURE-VOICES.md).

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

Current cold-loading work is indexed in
[Native loading optimization](NATIVE-LOADING-OPTIMIZATION-GOAL.md), with the six
original-binary comparisons, verified source checkpoints, complete offline-area
timings, current native/local regression receipts and explicit failed tests.
[Loading recordings](NATIVE-LOADING-RECORDINGS.md) describes private capture
integrity, missing dependencies and offline-only replay. These newer scoped
receipts do not imply that every earlier migration/parity limitation is resolved.
