# Complete base gameplay in the native Godot client

User-requested goal, 2026-10-26. Status: **active; incomplete**.

User desktop preference (2026-10-26): automated client launches and closures
must not steal foreground focus or capture/reposition the user's mouse. Use
headless checks where appropriate and non-activating/minimized launches for
background work. Do not restore or foreground the game automatically. The user
will bring it forward when ready; only activate it on an explicit request.
Do not treat minimized/background rendering as a representative FPS benchmark.
Open on a non-primary monitor whenever one is available; discover the current
monitor layout at launch rather than assuming that screen 0 is primary. Fall
back to the available screen on a single-monitor setup.

**Top requirement: behavioral parity and interoperability with the original
NWN binary.** We intend to play alongside users of the native client on unchanged
original servers. This requirement governs implementation choices and completion
for every feature below; basic connectivity alone does not satisfy it.

User priority clarification (2026-10-26): **base-binary parity is a top
requirement for the entire goal.** We intend to play in the same multiplayer
sessions as unmodified native-binary users. Every gameplay, menu, interaction
and transition milestone must preserve that interoperability, and completion
requires paired-client evidence on an unchanged original server.

When an implementation shortcut conflicts with native-client interoperability,
preserve the original client/server behavior. Mixed-client localhost validation
is a completion requirement, not an optional follow-up.

Deliver a client that can actually play the original game alongside the
unchanged original server. Native Godot owns presentation and client gameplay
behavior; the server owns rules, scripts and authoritative outcomes. Keep the
original models/textures, server resource precedence and existing allowance for
engine lighting differences. Existing full-native migration, streaming,
performance and reference-wiki goals remain open.

Parity covers protocol behavior, server-authoritative outcomes, movement and
collision, action/casting timing, targeting and range, animation/event ordering,
inventory and menu actions, party/remote actor state, resource/rule selection,
and travel across areas and servers. Do not substitute client-only simulations
or custom server behavior for the original client/server contract.

Engine lighting differences remain permitted under the earlier user allowance;
they cannot change gameplay information, targeting, visibility or outcomes.
Menu adaptations are acceptable only when the original choices and actions
remain available and preserve their behavior.

## Working order

Latest user steering (2026-10-27): authorized live testing on the owned local
server, then manually rejoined Arelith to check loading and streaming. Prioritize
player-centered native streaming and investigate measured hitches. Automated
public-server connections remain unauthorized; the user selects/connects their
own server. Preserve focus/mouse and secondary-monitor launch preferences.
Particle optimization remains a separate workstream. See
NATIVE-PLAYER-CENTERED-STREAMING.md for154 current-source native assertions,
binary grid-order evidence, the failed local strafe check and open live hitch
acceptance. Full gameplay migration remains incomplete.

Latest user bug fixes: [doors, transitions, movement and loading](NATIVE-PLAYABILITY-BUGFIXES.md)
add native animated doors, transition selection polygons and sustained gait
looping; remove decoded model disposal/validation from shared cache locks and
spread retired-world destruction over bounded steps.1520 headless assertions
pass, including original physical door Parts and a real held-worker contention
check. Baseline logs retain35s apply/13s retirement frames and a57.7s playable
area. Actual post-fix server/visual/loading-time acceptance is pending. This
turn is **progress**, not completion; the previous turn made verified progress
on direct native script sounds and disconnect audio cleanup.

Previous feature integration: [direct native script sounds](NATIVE-SCRIPT-SOUNDS.md)
connects decoded server9/7 to original native source/profile/resource selection
and fixes voice/sound queue cleanup on disconnect.93 source-pinned headless
checks and15 protocol/audio checks pass; actual server/device/mixed-client
acceptance remains open. This turn is **progress**, with the user's preview
preserved and automated graphical/live tests still paused. The preceding turn
launched and verified the requested preview; it did not complete gameplay parity.

Previous combat integration: [native creature voices](NATIVE-CREATURE-VOICES.md)
connects combat barks and decoded server26/1 with original SSF gates, priorities,
BMU/native decoding, current actor source positions and guarded worker/mixer
retirement.1025 headless assertions and5 protocol transport cases pass. Actual
server/device/mixed-client acceptance is queued; quick-chat, weapon audio and
direct-native script-sound forwarding remain open. This goal turn is **progress**,
not completion; the previous turn made verified progress on special initialization.

Previous combat integration: [special initialization and level20 eye effects](NATIVE-SPECIAL-INITIALIZATION.md)
uses original gate/stance/cache/resource/table semantics with native workers,
physical head Parts and guarded lifetime cleanup. Original instruction cases and
headless original-model/combat regressions pass1901 assertions. Actual localhost
and paired-client visual/outcome acceptance remain queued during the user's
testing pause. Equipped-weapon attack visuals also have component acceptance.

Previous combat integration: [equipped-weapon attack visuals](NATIVE-EQUIPPED-ATTACK-VISUALS.md)
connect original body blur events to native slotFB, ItemClass-derived resources
and colour scope4, preserving attack-window, equipment/lifetime and cleanup
ownership. Original transition/colour corpora and headless actual-model,
unarmed/casting/UI regressions pass. Real localhost pixel/outcome and paired
client acceptance remain queued. Native item Examine also has component
acceptance; wider gameplay and paired-client completion remain open.

Latest feature integration: [native item Examine](NATIVE-EXAMINE-ITEMS.md) now
displays received properties using active subtype/cost/parameter 2DAs and native
TLK text, plus disclosed item facts. Asynchronous completion preserves target,
revision and menu stacking. Headless custom/original resource and text/UI
regressions pass; visual/local-server acceptance is queued, not claimed.

Previous particle priority (currently paused): make particles usable before continuing the remaining
combat/menu work. Profile real original-server impacts with particles enabled,
remove avoidable collision/presentation overhead while retaining original
behavior, and resolve intermittent missing impact output. The user's existing
default-off preference remains until explicitly changed; hiding particles is
not acceptance of this work. Local-only tests and the full parity goal remain.

User-requested optional visual tradeoff: Options → Graphics → Particle collision
and bouncing now disables scene collision checks while retaining particle
simulation/drawing. Defaults on; overall particles still default off. An actual
12-Heal localhost comparison reduced particle callback p95 from43ms to9ms;
frame interval p95 fell from57–59ms to23–24ms. Diagnostic attribution only,
not clean FPS acceptance. See the particle performance note and retained reports.

Scoped progress: [particle collision and Heal sparkles](NATIVE-PARTICLE-IMPACT-PERFORMANCE.md)
now use native original-face/Part queries and persistent bouncing sprites. Local
Heal collision p95 falls from roughly9ms to2.1–2.3ms, with visible effect and
original-output checks. Broader-room performance, unsupported emitters and full
particle parity remain open; this does not complete the overall goal.

Latest shield follow-up: actual unchanged-server small/large/tower blocks embed
original ammunition in physical held-shield Parts. Read-only original loader
evidence corrected WeaponWield versus WeaponType, and native attachment ordering
now follows the current animated shield pose. See
[NATIVE-SHIELD-IMPACTS.md](NATIVE-SHIELD-IMPACTS.md). A retained intermittent
shutdown timeout remains unresolved; clean repeats do not erase it. Weapon
effects, reaction/death/audio, broader clocks/content and paired-client
acceptance still block full combat and the goal.

Next effect-owner research and936 unchanged-instruction cases are indexed in
[NATIVE-SPECIAL-ATTACKS.md](NATIVE-SPECIAL-ATTACKS.md). They establish original
special-attack gate/load/play behavior, not a completed Godot implementation.

Latest parry follow-up: original mode0 placement and native independent area
sparks are connected to real melee parry callbacks. Current-source local server
parry pixels/retirement, original placement/event corpora, source-independent
lifetime, stale model rejection and gameplay/casting/bow/Prelude regressions
pass. See [NATIVE-PARRY-VISUALS.md](NATIVE-PARRY-VISUALS.md). Literal repeated
original event entries are preserved; complete upper native Hit-listener and
paired-client effect-count acceptance remains open. Shield/weapon effects,
reaction/death/audio, broader clocks/content and terrain gaps still block the
full goal. This does not complete combat or base gameplay.

Latest hit-visual follow-up: mode1 blood selection, original three-slot
retention/reuse, physical body attachments and scene collision now run natively.
Real unchanged localhost server melee/bow hits draw original effects and retain
their authoritative results. Settings, casting and repeated Prelude lifecycle
regressions pass. See [NATIVE-BLOOD-VISUALS.md](NATIVE-BLOOD-VISUALS.md).
Full parry/shield/weapon effects, complete original BSP/normal/clock/shape behavior,
reactions/death/audio, terrain gaps and paired-client acceptance remain open.
This is scoped progress, not completion of combat or base gameplay.

Latest casting follow-up: the direct native entry owns original conjure/release
models, native chant/silent selection, fade callbacks and cleanup intervals.
Immediate decoded casting fields prevent a new cast using old snapshot metadata;
original model Detonate events now reach the appropriate Explosion parts.
Actual localhost Fireball/Magic Missile and native model-owner checks are
documented in [NATIVE-CAST-VISUALS.md](NATIVE-CAST-VISUALS.md). Full impact,
reaction/death, broader spell/shape/clock coverage and mixed-client acceptance
remain open; this does not complete combat or the goal.

Latest scoped combat milestone: native sling hit/miss bounces and genuine
original-server Deflect Arrows now have original-builder/polygon, conservative
static scene/WOK query, real localhost flight/outcome and cleanup evidence.
See [NATIVE-SPECIAL-PROJECTILES.md](NATIVE-SPECIAL-PROJECTILES.md). Full static BSP,
shield/impact/release behavior, reactions/death, visible terrain gaps and paired
original-client acceptance remain open. This does not complete combat or the
goal. Current desktop startup behavior and its separate evidence are in
[NATIVE-WINDOW-STARTUP.md](NATIVE-WINDOW-STARTUP.md).

1. Audit the actual default `join-native.ps1` entry and build an evidence-backed
   feature ledger. A component working in an older isolated launcher does not
   establish integration in the current client.
2. Complete combat/casting presentation: action/animation queues, melee/ranged
   attacks, casting stages, reactions, damage/death states, projectiles, impacts,
   effects, sound and timing. Keep server events and visual results aligned.
3. Complete travel: doors, interactable portals, teleport/scripted transitions,
   trigger polygons and zone edges, return trips, and cross-server handoffs.
4. Close remaining player menu, interaction, input and content-compatibility gaps.
5. Run end-to-end original-campaign playability and repeated multiplayer lifecycle
   scenarios. Maintain verified source backups at substantial changes.

## Acceptance ledger

Each row needs current default-entry evidence, a recorded result and explicit
remaining gaps. Implemented handlers, UI-only tests or historical isolated
successes alone do not satisfy these rows.

| Group | Required player behavior | Current starting point / missing acceptance |
|---|---|---|
| Binary parity and mixed-client play — highest priority | Our client and the original native client coexist on unchanged servers and agree on authoritative state, actions, timing and transitions | Required throughout; systematic paired-client acceptance remains open |
| Admission and characters | Server selection, creation, vault selection, entry, advancement, export where allowed | Native creation and accepted levels have local evidence; broader base classes, errors and default-entry coverage remain |
| Movement and input | Click movement, WASD, walking/running/strafe, collision, camera, targeting/cursors, highlights, keyboard/menu coexistence | Native prediction and collision have owned-Prelude evidence; broader controls, devices and latency correction remain |
| Combat and casting | Melee/ranged attacks, skills/feats/item powers, spell families/preparation/quickbars, AoE targeting, modes, buffs, shapeshifting, rest and death/recovery | Direct-native cast/attack clips, GPU mesh deformation and model hit events pass alongside real requests, consumption, familiar actions and cancellation. Ordinary effects/audio, type-11 area visuals, a real beam and server-timed homing Fireball have scoped local evidence. Ordinary bow shots now pass real server ammunition/outcome, flight, weighted body attachment and expiry checks; native material controllers/retirement are corrected. Stored binary cases cover ranged receiver/impact/finite orientation. Specialized ranged/reaction/death, projectile/release paths, broader effects/audio and mixed-client acceptance remain. See NATIVE-COMBAT.md, NATIVE-DIRECT-EFFECTS.md, NATIVE-POINT-AREA-BEAM.md, NATIVE-PROJECTILES.md and NATIVE-RANGED-PROJECTILES.md |
| Ordinary player menus | Inventory/equipment/creature-slot option, containers, record, spellbook, quickbars, party/associates, journal, map/pins, options/main menu | Native desktop/actions have partial real-server evidence; complete interactions, layout and state refresh need systematic acceptance |
| World interactions | Examine, conversation/replies, chat/feedback, use, loot/pickup/drop, doors, merchants, locks/traps, applicable skill actions and crafting | Dialogue, equipment, potion use and real merchant transactions pass; broader interactable/skill/item cases remain |
| Area travel | Door/portal use, trigger/zone-edge entry, teleportation, return visits, correct camera/player placement and loading gates | Owned-Prelude door/return checks exist; interactable/trigger travel and direct-native handoffs need full acceptance |
| Multiplayer lifecycle | Server rejection, cancellation at every load stage, disconnect/reconnect, area changes with pending assets, late packets, party/remote actors, handoffs | Latest disconnect/streaming/reconnect checks pass; broader repeated travel/transfer and pending-effect cases remain |
| Content and presentation | Active server 2DA/TLK, HAK/NWSync/Workshop precedence, original appearances/equipment/clips, lighting, effects and audio | Native resource readers and table-driven UI exist; broader base/mod resources, complete visible cues and failure isolation remain |

Server-specific menus and extensions must remain compatible. They do not replace
the original campaign/player acceptance route or take priority over blocking
base-game gaps. Track unsupported branches honestly rather than fabricating
server outcomes or showing a successful action without evidence.

## Test policy and completion

- Automated connections use owned localhost servers. The original campaign
  **Prelude** is the ordinary baseline; isolated original-server fixtures cover
  controlled combat, trigger/portal and handoff cases. Existing captures support
  resource/rendering regressions. No automated Arelith/public connections without
  new explicit authorization.
- Research the original binary read-only when behavior is uncertain. Record
  target hash, addresses/call sites, observed behavior and inferred adaptations.
- Include paired-client localhost scenarios using our client and the unmodified
  original client on the same owned server. Verify what both players observe:
  movement, combat/casting, equipment, party state, interactions and transitions.
  Use separate authorized test identities where concurrent admission requires
  them. Preserve unrelated user sessions. A pass only within our client cannot
  establish mixed-client parity.
- Check actual server changes and their native presentation together: spell/item
  consumption, damage/action feedback, queued cancellation, animation/effect
  timing, area/connection ownership and final character state.
- Exercise cold/warm entry, travel out and back, failure/cancel/retry, rapid area
  replacement, remote actors arriving/leaving, and pending asset/effect cleanup.
  Discard stale work without breaking the new world or blocking control.
- Preserve unrelated games/editors and user sessions. Pin sources during native
  tests; use the existing normal-heap exception-capture and lifetime checks.
- Record loading, frame pacing and memory on complete moving scenes. A partial
  or frozen scene, a high instantaneous FPS counter, or a unit-test count cannot
  establish playability. Keep the existing performance goal open until accepted.

The goal is complete only when binary parity and mixed-client interoperability,
the core player route and all ledger groups have
repeatable end-to-end evidence, necessary visible review, and no unresolved
blocking crashes, missing core controls or placeholder routes. Keep remaining
fidelity/compatibility limitations visible. Full removal of the transitional JS
protocol runtime and the final easy-reference wiki remain part of the existing
broader migration goal, rather than being silently declared done here.

## Starting evidence

- [Native desktop](NATIVE-GAMEPLAY-DESKTOP.md) and
  [server-confirmed actions](NATIVE-PLAYABILITY-ACTIONS.md).
- [Movement prediction](NATIVE-DRIVE-PREDICTION.md) and
  [disconnect/cancellation](NATIVE-DISCONNECT.md).
- [Owned-server transitions](NATIVE-WORLD-TRANSITION-CHECKS.md).
- [Campaign baseline](LOCAL-PLAYABILITY.md),
  [full migration](MIGRATION-GOAL.md) and
  [binary-guided streaming/research goal](BINARY-WORLD-STREAMING-GOAL.md).

Historical documents retain their original scope. Read their later follow-ups
and the current direct-entry source before treating an older status as current.
