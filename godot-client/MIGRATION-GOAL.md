# Full Godot migration — multiplayer first

Status: **active; incomplete**. The user explicitly requested this goal after
the owned-local-server connection milestone. All existing replacement-client
features are in scope. The latest user instruction is **fully native Godot
ownership**, including resources, world construction, networking and services.
The JS backend is transitional reference code, not the final runtime. See
[NATIVE-OWNERSHIP.md](NATIVE-OWNERSHIP.md) for the implementation and remaining
order. Original models, textures, UVs and gameplay behavior
remain requirements; engine lighting differences are allowed.

Weather follow-up: original byte/BOOL packet handling, physical WeatherTypes
metadata, float32 fade state and six-model lifetime plan are locally verified.
Original rain/snow rendering and live area/quit cleanup now have local evidence,
but a native crash remains unexplained and lightning/audio/timers are incomplete.
This is a work-in-progress stage, not weather or migration acceptance. See
[NATIVE-WEATHER-RENDER.md](NATIVE-WEATHER-RENDER.md).
The particle material-lifetime follow-up reduces draw-material allocation
churn while preserving GPU pixels/streams. Five genuine cold-compile local
runs and an explicitly self-tested exception-capture harness add stability
evidence; the earlier heap fault remains unexplained. See
[NATIVE-PARTICLE-MATERIALS.md](NATIVE-PARTICLE-MATERIALS.md). This does not
replace remaining UI/rendering/combat or full multiplayer migration work.

## Priority and acceptance checklist

Latest user direction (2026-10-24): **get the game rendering**, with further
performance experiments deferred. Use the original **Prelude** campaign on the
owned localhost server as the playability baseline. A static captured room or
scripted fixture pass does not establish campaign playability. Native resource
and scene ownership remain required; the current transitional multiplayer path
is a comparison/reference until the direct native renderer is integrated.
See [LOCAL-PLAYABILITY.md](LOCAL-PLAYABILITY.md) for the acceptance route.

Current user-directed work sequence (2026-10-24): **remove JS runtime
ownership**, starting with native resource/model loading and direct scene
assembly to eliminate whole-area GLB conversion, then native protocol/content
and remaining services. The previous sequence (2026-10-23) was **UI first, then rendering,
then combat**. Finish the native player HUD and party controls,
remaining gameplay-window/NUI behavior and native menus/settings/workshop/debug
flows before returning to rendering and combat presentation. This changes the
working order, not the full migration scope or its evidence requirements.

| Order | Feature group | Current native status | Evidence required before completion |
|---|---|---|---|
| 1 | Local admission, protocol ownership, encrypted login, resource admission | Partial: native selector; installed/saved character admission, export/save/reconnect/close verified on owned Prelude | Native creation core now implemented; broader failures/timeouts, frontend preview/audio and complete character presentation remain |
| 2 | Live replicated world and transitions | Partial: real A–B–A, retired in-flight content, owner release, reset-generation reconnect and per-object model updates verified locally | Metadata/per-part visual deltas, extended failure/stress transitions and reconnect with pending jobs, cross-server transfer and full resource lifecycle |
| 3 | Animated models, equipment and effects | Partial: native clips/GPU skins, body/robe locomotion/cast/attack cues and hit events, P/Q-only attachments and local shape/clothing replacement verified | Exact blends and broader event coverage, model/material/light/emitter controllers, exact skin picking, broader equipment/mount/custom-content coverage |
| 4 | Movement, camera, picking and interaction | Partial: native predicted motion/gait/facing, original drive/stop/turn requests, reused exact collision/path repair, live chest slide, menus/text focus and transitions/reconnect verified | Broader movement feel/latency/devices/control flags, interaction/portal targets, combat/correction blends, complete input/focus and picking coverage |
| 5 | Chat, dialogue and examine | Partial: native rich text, real server conversation/reply/end/abort, examination/portrait, token/RGB preservation, chat and script overhead prompts verified locally | Broader item/trap/effect/feedback branches, native bitmap fonts, speech portraits/audio, health/reaction nameplates, full input/layout and all channels' real server checks |
| 6 | Combat, spells, feats, targeting and quickbars | Partial: radial/target/cursor/quickbar/family paths plus native timed cast/attack/hit/reaction presentation and actual controlled GPU deformation verified locally | Broader combat rounds/ranged/death/shape, projectile/effect/audio, exact blends, AoE drawing, broader real feat/item/script targeting, full assignment menus and quickbars |
| 7 | Inventory and player windows | Partial: native party portraits/eight HUD controls/player list and buff/status HUD, spellbook, inventory/equipment, primary containers, merchant core, controlled-player record, seven-page server-confirmed level-up, map and four-category journal; original icons/art, shortcut assignment/save and simultaneous-menu movement; creature slots via Options | Broader status-icon catalogs/fidelity, full store quantity/infinite-stock/restriction/failure/race coverage, alternate/nested containers and remaining item actions, record associates/custom-content/input/skin, broader level-up/map/journal branches/failures/transitions, populated world-journal/notes, broader skill outcomes and shortcut categories, broader party/associate/second-player attitude coverage and remaining creator preview/audio/fidelity |
| 8 | Full NUI | Partial: all 21 controls, eight draw primitives, watched bindings, original art/fonts/skin, server targeting/casts and embedded popups pass actual local reconnect checks; batched text themes retain native selection | Huge Unicode layout/editing (native insertion crash retained), pending-work live stress, broader skin/actions/popup/device coverage and full parity |
| 9 | Menus/settings/workshop/debug/audio | Partial: native Main Menu/Options and Direct/History/Favorites browser, transient login and pending-login cancellation; Workshop root/per-mod global HAK selection, Windows-protected CD-key editing, five-tab separate debug OS window and compact FPS preference; locally verified alongside persisted movable menus | Public discovery/login/handoffs, broader frontend and remaining creator preview/audio/description/skin/device fidelity, remaining graphics/camera/feedback preferences, interactive debug/inspector coverage, sound/music/voices |
| 10 | Remaining local game systems | Pending | Module/save/campaign startup, script VM/scheduler/rules/action ownership, offline UI and behavior, saves/loads and transitions |
| 11 | Loading, resource ownership and performance | Pending complete moving world | Cached preparation, workers, lifetime cleanup, fidelity review, profiling, complete captured/local moving scenes, sustained >=60 FPS objective; no frozen-scene promotion |

The ordering is multiplayer first. Content/animation/input work needed for
multiplayer precedes additional single-player migration. Offline protocol and
resource tests are reusable, but browser/UI tests do not prove Godot behavior.
Mark each feature complete only with a native counterpart or a documented
reused backend path plus relevant native integration evidence.

## Coverage ledger and source baseline

`migration-inventory.json` records every current JS/CSS module in `src` and
`electron`, its hash, an initial group, migration review state, and the existing
test-file inventory. `needs-classification` explicitly remains review work.
This avoids relying only on the remembered features in chat. Review entry
points and dependencies, map each module's behavior to a feature above, and
record its native counterpart/reuse decision and validation. Do not silently
drop inactive-looking, server-specific or fallback behavior.

Generate a new baseline deliberately with
`node godot-client/tools/migration-inventory.mjs`; do not overwrite completed
review annotations with a regenerated pending ledger. Update the ledger as
systems move. Keep the old working client intact until migration acceptance.

## Current evidence and next work

See [LOCAL-MULTIPLAYER.md](LOCAL-MULTIPLAYER.md) for the successful real local
join, 375-mesh native import, chat round trip, authoritative and rendered
movement/camera checks. [NATIVE-MODELS.md](NATIVE-MODELS.md) records the newer
native animation/GPU skin milestone and its remaining gaps. Same-area native
spawn/model replacement now passes authored ownership checks and actual local
server-driven shape/clothing/removal tests; see
[NATIVE-WORLD-LIFECYCLE.md](NATIVE-WORLD-LIFECYCLE.md).
[NATIVE-AREA-TRANSITIONS.md](NATIVE-AREA-TRANSITIONS.md) adds real A–B–A with an
uncommitted old-area model job, actual native owner release and saved-character
reconnect with reused IDs/generation. [NATIVE-MOVEMENT.md](NATIVE-MOVEMENT.md)
adds native motion and original keyboard timing/packets with reused collision
planning, live slide/menu/focus checks and movement across transitions/reconnect.
[NATIVE-GAMEPLAY-TEXT.md](NATIVE-GAMEPLAY-TEXT.md) adds actual server examination,
portrait, dialogue/reply/abort, tokens/colors and overhead prompts with native
menus and bounded asynchronous delivery. [NATIVE-ACTIONS.md](NATIVE-ACTIONS.md)
adds scoped native radial menus/icons/counters, typed targeting and original
cursors, real local Examine/Talk and a prepared Light cast with server-observed
use consumption. [NATIVE-SPELLBOOK.md](NATIVE-SPELLBOOK.md) adds native books and
quickbars, actual family-child drag/casting and server-owned preparation. The
next [combat milestone](NATIVE-COMBAT.md) adds native queued cast/attack/reaction
playback and original hit events, with actual controlled GPU deformation. The
remaining foundations include effects/projectiles/controllers and player
windows, alongside remaining interaction/target coverage and metadata/per-part
visual deltas and controllers. [NATIVE-PARTICLES.md](NATIVE-PARTICLES.md) now
records live emitter/texture discovery, native frame/rig/controller sampling,
worker simulation and bounded binary transport. Actual installed flame pixels,
local dialogue, A–B–A and save/reconnect pass. Reference targets, wind/tint,
static-model animated ancestor transforms, full effect/projectile semantics and
dense-scene performance remain open; partial particle support is not parity.
[NATIVE-REFERENCES.md](NATIVE-REFERENCES.md) adds physical reference endpoints,
native attachment/revision guards and moving linked-beam worker/Vulkan tests.
Full retarget notifications and actual server effect/projectile spawning remain
required, alongside the existing actual local regression coverage.
[NATIVE-VISUAL-MODELS.md](NATIVE-VISUAL-MODELS.md) adds independent render-only
model resources, actual original installed-model import/animation/drawing, and
private player/skin/reference attachment/retirement checks. Live server effect
rosters, original phase/program owners and projectile paths remain required.
[NATIVE-VISUAL-PHASES.md](NATIVE-VISUAL-PHASES.md) adds the native phase clock,
direct replay of 688 retained original phase observations, original-loader
definition preparation and a per-world imported-resource cache. Native live
effect lists and basic placement/playback now have an actual local integration
in [NATIVE-LIVE-EFFECTS.md](NATIVE-LIVE-EFFECTS.md): 16 dialogue/examine checks
and 11 server-effect checks pass. Selection, scoped asynchronous delivery,
private emitters, expiry and instant retirement are connected.
[NATIVE-EFFECT-ANIMATION.md](NATIVE-EFFECT-ANIMATION.md) adds native binary-model
stacked runs, controller fields and real local Healing playback. Full programs,
decoded-only playback/controllers, specialized providers, dummies, projectiles
and pending-effect transition/reconnect acceptance remain open.
[NATIVE-INVENTORY.md](NATIVE-INVENTORY.md) adds the native inventory/equipment
window and actual local acknowledgement/ownership tests, original item icons,
page selection, item radial/examine, options-only creature slots and simultaneous
spellbook/inventory movement. Containers/stores and remaining player-window
coverage remain required.
[NATIVE-CONTAINERS.md](NATIVE-CONTAINERS.md) adds actual chest use/status-driven
native opening, three-page contents, two-way server-confirmed item transfers,
close/reopen guards and the isolated installed-PLT icon compatibility adapter.
[NATIVE-STORES.md](NATIVE-STORES.md) adds actual merchant buy/sell/identification,
two-page stock/category navigation, native confirmation and independent windows,
and scoped item/context checks that tolerate unrelated arriving replication.
[NATIVE-CHARACTER-RECORD.md](NATIVE-CHARACTER-RECORD.md) adds the native controlled
Character/Skills/Feats tabs, actual stat subscription and timed server effect,
original portrait/icons, scoped shortcut drags and server-exported assignments.
[NATIVE-LEVEL-UP.md](NATIVE-LEVEL-UP.md) adds the native seven-page progression
wizard, real cancellation and two consecutive server-accepted levels with
independent exported-character verification. It also records a short dialogue
test's exit-leak failure and the corrected shutdown evidence gate.
[NATIVE-MAP-JOURNAL.md](NATIVE-MAP-JOURNAL.md) adds original map tile/marker art,
server-owned exploration/pin updates, native journal subscriptions/categories
and actual quest completion/removal. Actual WASD, outside-menu click movement,
camera rotation and close/reopen pass with both windows. It also traces and
fixes the earlier short-run leak: inventory's unopened AC label was unparented.
The original short dialogue flow now exits cleanly without opening inventory.
Loading hitches,
controllers/effects, broader movement/failure coverage and full feature
coverage remain open.

The newer native-selector smoke is `reports/native-lobby-local-v2.json` and its
screenshot. The original NWN client was preserved while running; after it
closed, the full local check completed. `reports/native-lobby-lifecycle-v1.json`
additionally verifies native export, save-on-disconnect, a second admission
using that saved BIC, live movement/chat/camera follow in both sessions, and
save-on-close with native exit 0. The three saved versions keep one vault ID
in a dedicated external temporary regression vault. No user vault overwrite
or public-server connection occurs. The first selector startup failure is
retained, and the real server-vault-only path still needs a dedicated check.
The v2 lifecycle adds BIC read-back hashes proving both preview and upload on
the second connection consume the first connection's saved character bytes.
Thirteen new coordinator cases and fourteen native selector UI cases pass.
The owned local server remains running on UDP 5121.

## Standing constraints

- Local server or captured data only. No Arelith connections until explicit new authorization.
- Preserve other games and unrelated servers; defer clean GPU measurements while they run.
- Credentials stay protected; do not log/copy keys or put them in command arguments.
- Proprietary asset payloads remain in the installation or external temporary runtime bundles.
- Make verified Godot checkpoints at substantial milestones, keeping failed checks and limitations visible.
- Migration remains active until feature coverage and integration acceptance are met. A successful login, frozen import or one benchmark does not complete it.

Native server NUI now has a verified local foundation: 21 control kinds, eight draw primitives, original fonts/artwork, watched typed bindings and canonical indexed arrays, nested resource-backed menus, complete toolbar height, simultaneous movement/camera input and A–B–A lifetime checks. See [NATIVE-NUI.md](NATIVE-NUI.md) for the 16+34 actual server checks, retained failures and remaining full-parity requirements.

NUI action completion also passes locally: two native server-target callbacks and a toolbar-triggered normal Light cast with actual prepared-use consumption (2 to 1), alongside the 16 dialogue +39 NUI checks and A–B–A cleanup. See [NATIVE-NUI.md](NATIVE-NUI.md); full styles, reconnect stress, other action types and performance remain pending.

NUI also passes a real saved-character reconnect: 39 +41 native checks across two sessions and six rendered area admissions, old window/font/image retirement and stale old-connection input rejection. See [NATIVE-NUI.md](NATIVE-NUI.md). Pending-resource races, full style/action breadth and moving-scene performance remain incomplete.

The installed NUI skin adapter passes 49 +51 actual local checks across saved-character reconnect, including original checkbox/radio, slider/progress, scrollbar, combo, editor and window-button artwork. Cached styles retire with the connection. Nineteen authored skin checks, fifteen native UI regressions and 52 Node checks pass. See [NATIVE-NUI.md](NATIVE-NUI.md); full state/pixel parity, popup behavior, pending-work races and performance remain incomplete.

Native embedded NUI popup input now passes 57 +59 actual local checks across reconnect: GUI opening, keyboard dropdown selection, typed color entry, complete popup pointer bounds and prior casting/movement/lifetime checks. A late localized projection can no longer repopulate a retired image queue. Sixteen native popup, eight authored pending-fragment, fifteen UI, nineteen skin and 54 Node checks pass. See [NATIVE-NUI.md](NATIVE-NUI.md); forced pending-work live reconnect, broader popup/state parity and performance remain pending.

The native buff/status bar now passes 17 +18 actual local checks over saved-character reconnect, including original icons/localized labels, server-driven expiry, MMB/WASD/outside-click movement, six animated area admissions and clean ownership retirement. Seventeen authored GUI checks and 66 Node regressions pass. See [NATIVE-STATUS-HUD.md](NATIVE-STATUS-HUD.md). Native settings/workshop/debug UI and broader status/fidelity/performance coverage remain. UI remains first, then rendering and combat.

Native party portraits, server-disclosed HP and the eight original HUD controls now pass 28 +29 local checks across saved-character reconnect and six animated admissions. Actual companion membership, portrait spell targeting, radial examination, Rest and simultaneous-menu movement are verified; the player-attitude window uses canonical private handles. Eighteen authored native GUI checks and61 Node regressions pass. See [NATIVE-PARTY-HUD.md](NATIVE-PARTY-HUD.md). Actual second-player attitude exchange, broader associates/fidelity, creation and remaining native settings/workshop/debug UI remain pending.

Native Main Menu settings now expose the Workshop root/per-mod global HAK toggles and existing Windows-protected CD-key store. The admitted world has a compact optional FPS counter; debug information opens in a separate five-tab native OS window. Twenty-five isolated Windows UI/store checks,34 +35 actual local reconnect/transition checks,20 authored GUI checks and119 Node regressions pass. See [NATIVE-FRONTEND-SETTINGS.md](NATIVE-FRONTEND-SETTINGS.md). Browser/creation, remaining preferences, audio, interactive debug/fidelity and other UI remain pending before rendering/combat acceptance.

Native creation now uses all fifteen pages, active package rules, original portrait pages and palette swatches, typed BIC submission and connection-scoped cancellation. Actual owned-local vault-policy creation/export/reconnect evidence is listed in [NATIVE-CREATION.md](NATIVE-CREATION.md). Creator preview/voice/help/fidelity and broader class/custom-content coverage remain open; the migration and performance goal stay active.

Native server browser now has locally verified Direct/Favorites/History, masked transient login fields, actual server query, atomic safe-metadata persistence and pending-login cancellation. The local regression passes 40 checks across native creation and two animated admissions;22 browser GUI,20 lobby,16 creator GUI and119 backend regression checks pass. See [NATIVE-SERVER-BROWSER.md](NATIVE-SERVER-BROWSER.md). Only localhost 5121 is enabled; public discovery/login/handoffs and broader UI/fidelity/audio remain open. The complete migration/performance goal remains active.

Native creation voice sampling now reuses original SSF cycling and resources with Godot-owned output, fixed-footer controls and selected-voice feedback. Actual WASAPI playback, native clock/checksum, soundset export and two animated admissions pass48 local checks;19 native audio,16/22/20 creator/browser/lobby GUI and135 backend regressions pass. See [NATIVE-AUDIO.md](NATIVE-AUDIO.md). Original-model appearance preview and broader UI/audio remain open before rendering/combat acceptance; migration/performance stay active and only localhost is enabled.

Native original-model appearance preview now has local evidence for head/clothing/palette changes, animated body parts, rotation/zoom, canonical export and two moving admissions:61 checks. Nineteen rendered and18 headless preview checks,16/19/22/20 creator/audio/browser/lobby GUI regressions and164 backend tests pass. Four GLB geometry/texture hashes are unchanged while idle-only metadata cuts transfer size about86%. See [NATIVE-CREATION-PREVIEW.md](NATIVE-CREATION-PREVIEW.md). Broader content/help/font/device fidelity and full UI/rendering/combat/moving-scene60FPS remain open.

NUI text themes now batch native notifications and preserve complete text and
selection. A cross-feature regression also restores embedded gameplay popups
while forcing only diagnostics into a separate OS window. The corrected local
run passes57 +59 NUI checks across saved-character reconnect and six animated
area admissions;25 actual Windows settings checks,13 rendered theme,17 popup,
21 settings GUI and29 backend checks pass. See [NATIVE-NUI.md](NATIVE-NUI.md).
The long-Unicode native insertion crash and huge document layout remain
explicitly unaccepted; normal-room checks do not accept them or60FPS parity.

The user has deferred the emoji/native-engine investigation. Its diagnostic
build is stopped, the production runtime is unchanged, and its retained
failures are not a blocker for ordinary migration work.

Native inventory-to-quickbar dragging now passes 20 actual local checks,
including original item icons and server-confirmed shortcut unequip/re-equip.
Twelve rendered synthetic GUI drag/ownership checks, 24 inventory, 22 spellbook
and 40 backend regressions pass. See [NATIVE-INVENTORY.md](NATIVE-INVENTORY.md).
Property assignment menus, broader activation/reconnect and device/fidelity
review remain open. The complete UI → rendering → combat migration and moving
captured/local-scene 60 FPS goal stay active; no public server was contacted.

Item-power wheel leaves can now be dragged onto the native quickbar using
original property/family/page choices, separate original power/item icons and
charge disabling. See [NATIVE-ITEM-POWERS.md](NATIVE-ITEM-POWERS.md): 58 backend,
13 rendered and 14 headless GUI checks pass, plus inventory/spellbook/action
regressions. Local v5 passes all 26 checks, both clears, four equipment
acknowledgements and exact potion consumption with clean shutdown. The user
authorized functional local tests alongside the preserved original NWN instance;
these runs do not accept clean performance parity. Migration stays active.

Native shortcut assignment menus now reuse the original data-only choice
builder and family/paged menu hierarchy. Right-click opens private item, spell,
feat, skill, ability and command choices; missing skill records are requested
from the actual server without opening a native character sheet. The latest
local check passes 34 cases, including Light consumption, Follow submission,
menu clears and prior item/power/input regressions. Seven authored rendered
GUI checks and 69 backend tests pass. See [NATIVE-SHORTCUT-MENUS.md](NATIVE-SHORTCUT-MENUS.md)
for remaining action, reconnect and fidelity limits. Original NWN and the
editor remain preserved during user-authorized local functional checks; no
public-server connection or performance acceptance follows.

Skill quickbar activation now has a native protocol adapter validated against
238 isolated original-code observations. The local regression passes 45 checks,
including targeted Heal submission, two Parry mode requests and the actual
Craft Trap server conversation, alongside prior inventory/spell/movement checks.
Seventy-five backend, seven shortcut GUI and 8,000 authored action checks pass
(the last count mainly covers the existing hit-band oracle). See
[NATIVE-SKILLS.md](NATIVE-SKILLS.md). Heal without an item can be silent in the
original handler; actual kit use and broader skill outcomes remain pending.
The migration goal stays active and incomplete, with no public-server test or
performance acceptance. Original-client processes and the editor are preserved.

Saved-character shortcut reconnect now passes 21 +15 native checks across two
animated admissions and 16 dialogue/examine checks in each session. Seven
bindings span three pages; exported/read-back metadata and actual activation
remain correct after a potion runtime-ID change. Native Ctrl+F events activate
restored equipment/item/spell/crafting shortcuts with inventory open, and old
buttons/textures retire. Incoming spell readiness is recorded independently
from exported BIC state. One hundred backend tests pass. See
[NATIVE-SHORTCUT-PERSISTENCE.md](NATIVE-SHORTCUT-PERSISTENCE.md). Broader custom,
family/feat/innate/charged/paired/pending-work cases and full migration, fidelity
and performance remain incomplete. Testing stays on the owned loopback server.

Native Game Options now includes persistent floating combat feedback and total
damage controls, with current-connection acknowledgements and live original
formatter options. Actual local damage messages verify 20 checks, unchanged user
configuration, independent server prompts/history and movement/camera through
simultaneous menus; 16 dialogue checks and one animated admission also pass.
Ten new native GUI, 21 existing settings GUI and 122 backend checks pass. See
[NATIVE-FEEDBACK-OPTIONS.md](NATIVE-FEEDBACK-OPTIONS.md). Remaining camera,
graphics, gore, audio and debug Options, real second-admission resynchronization,
full UI/rendering/combat and moving-scene performance remain open. The local
owned fixture is now GodotFeedback1; no public-server connection is made.

Native camera mode selection now persists Top-down, Chase and Stiff chase while
Godot owns the original follow/input/steering calculations. The current local
check passes 23 camera and 16 dialogue checks across three animated admissions,
with actual dropdown display, manual view preservation and released old camera
owners. Twenty-four native GUI and 139 backend checks pass; 1,655 retained
original observations pass 16,593 numeric/state comparisons. The area test also
found and fixed late particle requests reaching retired scopes; all workers
close with zero pending jobs. Existing settings and feedback regressions pass.
See [NATIVE-CAMERA-MODES.md](NATIVE-CAMERA-MODES.md). Scripted camera commands,
collision/clear-view, broader Options and full UI/rendering/combat/performance
acceptance remain unfinished. Testing remains on the owned loopback server;
other original-client instances and the editor are preserved.

The user prioritized NWSync before finishing scripted camera work. Native
NWSync progress/cancel/failure controls now use the existing backend unchanged.
The final owned-server/loopback-HTTP test passes actual cancellation (8 checks)
and cold/cached/corrupt-cache logins (10 NWSync +16 dialogue checks each) with
three animated admissions, all 13 mounted resources and a rendered downloaded
texture. Cold fetches 14 entries, warm fetches none and repair fetches one blob.
Twelve native GUI, 20 existing lobby and 187 backend checks pass. See
[NATIVE-NWSYNC.md](NATIVE-NWSYNC.md) for retained failures and limits. Camera
command math is ported/oracle-tested but its complete live check is still
unaccepted; collision/clear-view remains pending. The full UI → rendering →
combat and moving-scene performance goals remain active. Only localhost was
used; the ordinary GodotFeedback1 local server is restored and the editor stays
open. Public/Arelith authentication and handoffs still require integration.

The user subsequently observed native PGCC admission with the existing NWSync
cache, then prohibited online connections until returning. Explicit public
startup now permits user-selected addresses/history/favorites/Internet choices;
local tests stay restricted. Lighting retains source sunlight direction,
correct ambient input color space and solid background. Late transition regions
and actual hidden usable-placeable hit faces survive native transfer. Original
click assembly exposed a missing selected-trigger ID in movement packets;
correcting it enables a click-driven localhost A-B-A round trip: 14 native
checks, three animated admissions and no surviving retired owners. Eleven
offline Vulkan, 16 local dialogue/examine and 110 backend checks pass. See
[NATIVE-LIGHTING-PORTALS.md](NATIVE-LIGHTING-PORTALS.md), including retained
failures. Fog, sky, weather, dynamic lighting and cross-server handoffs remain
unfinished. The full migration/performance goal stays active.

Native area atmosphere now uses received sun/moon/fog state, fixed-night rules,
original day/night transition arithmetic and fog-color background. Godot owns
phase progression and zoom-dependent fog/far clipping without JS frame calls.
The original executable agrees with 6,468 exact numeric observations. Twenty-
three offline Vulkan checks, 16 ordinary local dialogue/examine checks and a
three-admission day/night/day portal round trip pass with zero retired owners.
See [NATIVE-ATMOSPHERE.md](NATIVE-ATMOSPHERE.md) for evidence, retained failures
and stock Godot fog approximation. Scripted lighting messages, pause/timing,
sky/weather, cross-server handoffs and full migration/performance remain open.
No online game-server connections occurred; only owned localhost and offline
inputs were used, and ordinary GodotFeedback1 was restored.

Cross-server handoff ownership is now hardened behind the still-disabled native
prepare hook. Prepared destinations are disposed during cancellation/frame loss,
late hooks cannot revive or replace a connection, native transfer cancellation
survives the no-session/resource intervals, and completion/failure releases the
lobby busy state. Sixty-nine backend/lobby/portal tests and ordinary localhost
animated admission plus16 dialogue checks pass. See
[NATIVE-PORTAL-WIP.md](NATIVE-PORTAL-WIP.md) for integration work still required.
This is not cross-server handoff acceptance; no online connections were made.

The native client now completes a real two-owned-server A→B→A in regression
mode: two downloaded characters/source releases, fresh identities and arrival
waypoints, three animated admissions,48 dialogue/examine checks, three correctly
owned character saves, zero retired native survivors and all worker epochs
released. Eighty-four backend/gate tests and an adoption-owner GC lifetime probe
pass. See [NATIVE-HANDOFF-LOCAL.md](NATIVE-HANDOFF-LOCAL.md) for the strict v5
report, retained failures and limits. Production adoption stays disabled pending
native cancellation/failure retry and NUI/server-vault/NWSync handoff checks.
Only owned loopback servers were used. Full migration/performance remain active.

Native handoff cancellation and actual destination unavailability now each pass
12 native recovery checks, pointer retry, two animated admissions,32 dialogue
checks and two owned character saves. Connect remains disabled throughout failed
destination cleanup; private downloaded character data is wiped. Successful
A-B-A still passes48 dialogue checks after the acknowledgement fix. Ninety
backend/gate tests pass and all native owners/particle worker epochs retire.
See [NATIVE-HANDOFF-RECOVERY.md](NATIVE-HANDOFF-RECOVERY.md) for retained failed
attempts and limits. Normal adoption remains disabled pending NUI/window/token,
server-vault reference and NWSync handoff integration. No online tests occurred;
the full migration and sustained moving-scene performance goal remains active.

Authored native NUI now survives real owned A→B→A correctly: old menus/resources
are retired, destination root/child menus use the new server's bindings and JUI
HAK content, and reused handles reject stale native/server inputs. All48 native
NUI checks,48 dialogue checks and106 backend/gate checks pass. See
[NATIVE-NUI-HANDOFF.md](NATIVE-NUI-HANDOFF.md) for failed attempts and scope.
Server-vault reference and NWSync transfers still precede normal-client adoption;
broader NUI/rendering/weather/migration/performance work remains incomplete.
All testing stayed on owned loopback servers with the editor preserved.

Both server-vault reference handoffs are now verified locally: source17 account
and source2 base vault each complete A→B→A, three animated native admissions,
48 dialogue checks and three canonical exports with no BIC upload/local read.
Fresh external profiles share an authored test vault; private preseeding proves
protected settings unchanged. Rigid-only actors require controlled locomotion
and imported zero-skin inventory; the ordinary BIC/GPU-skin regression passes.
124 focused checks pass. See [NATIVE-VAULT-HANDOFF.md](NATIVE-VAULT-HANDOFF.md)
for retained failures and scope. Production adoption remains disabled pending
cross-server NWSync content checks. The full migration/performance goal remains
active; no online tests occurred and the editor is preserved.

Distinct NWSync manifests now replace content across owned A→B→A:45 resource
hash/length checks, old unique markers absent, actual native menu texture pixels
changed/restored,48 NUI and48 dialogue checks. Two cold repositories each make16
successful HTTP requests; cached return makes none. Native admission stays
gated with Cancel available during download, all resources/workers retire and
175 focused tests pass. See [NATIVE-SYNC-HANDOFF.md](NATIVE-SYNC-HANDOFF.md).
Combined transfer/content cancellation and failure/retry still precede enabling
normal-client adoption. Ordinary GodotFeedback1 is restored, the editor is
preserved and no online connections occurred. Full migration/performance active.

Combined transfer/content recovery is now verified locally: native Cancel during
in-flight B downloads and required-data404 failure each pass18 recovery checks,
pointer retry,32 dialogue checks,31 NUI checks and two animated admissions/saves.
Private destination BICs are wiped; no failed B world is admitted; old native
owners and admitted-world worker epochs retire. Receipt-time advertisement
metadata survives cancellation. 180 focused tests pass. See
[NATIVE-SYNC-RECOVERY.md](NATIVE-SYNC-RECOVERY.md). Normal-client activation and
its regression follow this checkpoint; no online work or full parity claim.

Native server-requested transfers are now enabled in ordinary sessions within
the existing endpoint policy. The enabled A→B→A path retains full local NUI,
NWSync/data/pixel/cache and animated gameplay evidence. Normal startup without
a handoff-test flag passes16 dialogue checks and records the enabled binding.
Combined content cancel/failure recovery is rechecked after activation. A live
GC comparison also exposed and fixed destination diagnostic callbacks retaining
old source sessions/worlds; both are now collectible while the destination lives.
183 focused plus3 policy cases pass. See
[NATIVE-HANDOFF-ENABLED.md](NATIVE-HANDOFF-ENABLED.md) for exact reports, rollback
checkpoint and limits. No online connections occurred. Public acceptance, full
migration and sustained moving-scene performance remain incomplete and active.

The next rendering milestone adds original-model sky presentation in normal
native sessions. Active SkyBoxes rows resolve through the session resource
owner; four original phase models use a camera-centered pass and original
phase/alpha state rules. 570 original instruction comparisons,27 Vulkan checks,
real day/night/day local portals and the existing6468 atmosphere comparisons
pass. Fixed phases avoid repeated surface/uniform work. See
[NATIVE-SKY.md](NATIVE-SKY.md). The original horizon overlay, precipitation and
lightning, dynamic sky commands, broader settings/catalogs and public/performance
acceptance remain incomplete. No online connections occurred.

The native sky material/horizon follow-up now uses the original `skyfade1`
geometry/bitmap, received fog RGB, native normal-alpha blending and native
white phase modulation. Its18 material instances now share one shader program
per area.24 original-instruction material cases match native
shader pixels;35 original-asset Vulkan checks and24 replacement/render cycles
pass. A local shutdown0xc0000005 occurred once despite successful gameplay
checks; its cause remains unproven after clean debugger/non-debugger reruns.
The milestone stays work in progress for stability, with the prior558-file sky
checkpoint retained as last accepted rollback. See
[NATIVE-HORIZON.md](NATIVE-HORIZON.md). Full migration/performance remain active.

The intermittent shutdown failure was reproduced on the third repeated local
session. Native quit now explicitly retires active world/animation/effect/
particle/UI owners, waits for queue-free completion and a render boundary, and
reports retirement before exiting. Ten subsequent local A-B-A sessions pass
with18 retired world owners per session and zero tracked UI survivors. A real
two-server NWSync/NUI roundtrip also passes with zero remaining particle workers
and retired backend sessions/worlds collected. The host rejects exit-only,
stale, surviving-owner, forced or crashed shutdowns. See
[NATIVE-SHUTDOWN.md](NATIVE-SHUTDOWN.md). The exact original C++ fault instruction
remains unproven; acceptance is limited to this owned-local lifecycle evidence.
Full migration, public testing and sustained complete-scene performance remain
incomplete and active.

Location effects now use an independent native type11 owner for real decoded
area packets, preserving original model selection, impact animation, phase/AI
countdowns and retirement. Invalid-target object effects have a separate shared
private client-dummy allocator and original c_dummy anchors. Two frozen owned
local runs pass60 visual checks and32 dialogue/examine checks, with12 tracked
world owners retired and no survivors. Native fade/area state ports pass30,288
original-state/call comparisons. Dummy rendering/expiry is tested through
explicit authored adapter probes, not mislabeled as server packets. See
[NATIVE-POINT-EFFECTS.md](NATIVE-POINT-EFFECTS.md). Full VFX, projectile/audio,
world-clock scheduling, multiplayer migration and performance acceptance remain
incomplete; no public connection was made.

Effect impact/duration/cessation and received script-sound playback are now
owned by Godot. Source-scoped original audio bytes, mono/stereo gates, native
listener/height/delay rules, range parking and cache/lifetime behavior have
functional evidence. Stereo/WASAPI output tests pass40 checks each and524
original numeric comparisons pass. Native quit now observes actual stopped
audio playback references, including creation samples. The demonstrated mixer
retirement gap is addressed; the previous shutdown AV remains unexplained.
See [NATIVE-WORLD-AUDIO.md](NATIVE-WORLD-AUDIO.md). Music/ambient/placed/voice/
animation audio, mixer settings/priority limits, full multiplayer/performance
and public acceptance remain incomplete. The full goal remains active.
