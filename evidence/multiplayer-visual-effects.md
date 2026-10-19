# Multiplayer visual delivery and presentation — 2026-10-18

Latest follow-up: [Lightning particle chains](lightning-particles.md) now connects
the missing updater and first-direct-reference endpoint.2697+97 original cases,
52 focused checks/build/SP visual regression and WebGL replayv5 pass. Actual
installed cold beam now has both connecting Lightning chains; moving endpoints,
removal and canonical immutability are checked. Full event/cache/render parity
and a live/original-client beam comparison remain open. User v84 stays untouched.
This supersedes the older Lightning-unavailable milestone below.

## Latest: live rendering correction and beam attachment

The earlier offline milestones did NOT establish live visual acceptance.
User subsequently authorized reconnect/effects testing. v81 closed normally;
unchanged vanilla server20964 stayed running. Real runv82 delivered three6/9
potion uses, three5/3 instant visuals, drink animations and healing particle
vertices. However PNG review and the runtime log exposed THREE shader errors:
fragment sampler count exceeded MAX_TEXTURE_IMAGE_UNITS16. The world was blank.
This is retained as a FAILED RENDER run despite successful protocol/CPU state.
The initial commentary called it a pass before that review; the correction was
reported to the user. v83 also retains an Item power entry unavailable input
timeout; it is not counted as acceptance. No cause beyond the captured state
is inferred for that timeout.

RendererShadowBudget now reserves material/spot/environment sampler needs and
limits shadow-map samplers to the actual renderer capability before drawing.
ALL light colors/intensities and native/authored shadow requests survive;
requests can be restored when space becomes available. Native model/tile
shadow setters retain requested state independently of GPU admission. The
fallback chooses directional then nearby shadows; it is explicitly diagnosed
renderer.shadow-budget-partial, NOT a port or proof of native per-object light
selection/cache policy. This is a hardware safety boundary. That native owner
remains required for parity. Local Three WebGLPrograms/WebGLLights corroborate
the per-shadow sampler allocation; the actual failing GPU compiler log and
corrected live screenshots validate this incident.

User's top-left Waiting for the server was an initial HUD label left unchanged
after entry, not a failed handshake. Successful area entry now says Connected.
Subsequent action feedback still replaces that label normally.

After normal close ofv83, corrected interactive v84/PID39408 joined the same
server. Actual inventory-power drag, inventory close and hotbar use consumed
one potion (stack3->2) and produced native visual66/vim_heal02. The effect PNG
is written ONLY when the received visual is ready and actual healing model
particle vertices are positive. Its inspected image shows the world and
healing particles with inventory closed; readiness PNG shows the world after
retirement. Frozen readiness/diagnostics record zero runtime errors/sample
failure. No additional scripted inputs remain. v84 is LEFT OPEN for the user.
Its complete wire/request report is written only on normal close; that pending
report has not been used as current evidence. Open stdout/stderr, live JSON
and controls must stay out of archives. Full original-client concurrent play,
healing from injury, audio and visual parity are not proved by this check.

### Beam owners

Same read-only nwmain build/SHA below. Full attachment14096ba80..14096bbab
looks up target then source, binds procedural B8 to the SOURCE model/anchor via
virtual98, reloads B8 and reattaches references to the TARGET via virtual150.
Source/target handles use virtual140(255,1). Start14096a110 TYPE7 requires D8,
attaches, reads Param6 (even failed-query output) and invokes animation speed1,
flags0,time0. Stock Param2 values that look like clips are NOT used by this
owner. Stop14096fa90 TYPE7 unparents and reloads B8 for scene removal.

inspect-native-visual-beam.py executes full attachment and full original
start/stop dispatchers restricted to Type7:1418 cases, including missing
objects/views/handles/model, nullable anchors, failed-query defaults, D8 gates
and callback model replacement. Lower model/reference/animation/string services
are captured boundaries; original reference traversal has its existing separate
oracle. visual_beam.js preserves that order and plugs into shared SP/MP visual
phases. Network visual resources now prefetch reference children through the
scene cache and create independent ModelReferenceScene instances. Updates and
destruction stay owned by the visual, without canonical object/effect IDs.

52 focused checks and production build pass. Actual installed vim_raycold plus
two fx_ref_cold children attach to caster/target, follow both moved bodies and
all release on removal, leaving canonical registry identical. Electron replayv3
renders the supported beam endpoint/Fountain subset (858 vertices), but BOTH
Lightning emitters remain explicitly unavailable. Its PNG was inspected and
shows that incomplete subset, not a complete beam. Actual captured potion/point
regressions also pass. This newer beam/reference build is NOT loaded inv84;
the live session contains the shader/HUD fix. Full beam rendering remains OPEN:
Lightning update/endpoint sampling and native attachment/scene lifetime need
work, as do other procedural types, audio and native lighting selection.

Full multiplayer objective remains active. This milestone connects received
object visuals and looping visual changes to existing native-compared visual
phase/model owners. It does not implement local spell or effect resolution.

Read-only installed nwmain89.8193.37-17 SHA256:
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Original executables/Ghidra were unchanged. Existing REA session91238 reused.

## Original evidence

CNWSMessage::SendServerToPlayerGameObjUpdateVisEffect4d9640 sends major5/minor3.
Client receiver7857f0 reads target ID, visual WORD and three FLOATs. Exact
Type_FD P/B or native999 adds source ID, two BYTE part fields, source position
and duration only for OBJECT_INVALID target. Negotiated8193.14+ adds the
visual-controller map. Read positions use scale1/32 bits. The real v80 potion
capture contains three162-byte5/3 packets for visual66, target0xffffffff,
position[6,3,0], full key0 default controller channels. Earlier18/8 packets
are a different unsupported family and are not mislabeled as these visuals.

Network looping receiver7b1f00 reads A/D plus visual WORD. Exact P/B reads
source ID and source-part BYTE; other rows use OBJECT_INVALID and zero. A
calls virtual178 with instant0, target equal to receiving object, target-part0
and point[0,0,0]. D calls virtual180 with visual WORD only. Its underlying
client add762180 allocates a visual, invokes loader96cf10, appends to linked
list80, starts/places/detaches and selects the visual group. This is separate
from server AddLoopingVisualEffect48da00.

Client remove762ad0 scans from the HEAD, skipping null, different visual,
finishedF4 and actual HasCessation96c610 entries. It detaches a competing effect,
calls Stop971530 with1 and selects the group. It does not immediately remove
the physical client list node. Server looping-array removal instead searches
backwards; reusing it here would remove the wrong duplicate.

inspect-native-client-visual-remove.py executes the full original removal
body and actual type/cessation getters in100 cases/300 calls. Traversal,
competing detach, stop and group-selection are captured boundaries. Stop's
independently verified finish write is retained across calls. Tests compare
the selected physical entry, return value, callback order and group type.

Transform leaf writer596610 calls native IsIdentity helpers before compact
TRUE; otherwise it writes ten curves through596980. The existing map reader
retains both key and value passes. The current presentation admits empty,
compact identity and a single key0 constant default channel set only. All
other scoped/animated/non-default maps remain retained and diagnosed.

## Client connection

network_object_visual.js decodes5/3 with native field/version gates and strict
reader completion checks. NetworkFrontend routes the event separately from
replicated gameplay updates. Existing NetworkWorld visual-effects events now
reach NetworkVisualPresentation instead of only producing the old generic
network.scene-effect-unhandled warning.

The presentation owns separate stable render facades/client visual lists,
keyed by the unchanged server-assigned uint32 object ID. Canonical proxies,
uint64 gameplay effect/property IDs, ownership, inventories, rolls and scripts
are untouched. No game-effect ID is allocated for a visual. Logical physical
ordering preserves duplicates and pending loads. Adds/removes serialize through
an independent presentation queue; a failed delivery is logged and does not
poison later events. Late work checks original canonical object and area.

LoopingVisualPresentation and createVisualSceneRuntime supply the existing
native loader, selection, start/placement, attachment, stop/cessation and
retirement owners. Resources use active visualeffects/progfx/appearance tables
and the scene asset cache. Only the runtime advances its effect animators;
they are not also registered in the scene's ordinary animator list. Body
rebinding retains phase/model identity and reattaches against the new body.
Area disposal cancels late loads and releases instances before scene assets.

Normal targeted instant effects reuse deliverObjectVisual. Point/source/target
dummy creation is explicitly diagnosed; no canonical placeholder object is
fabricated. Unsupported transforms, non-creature prefixes, procedural types,
audio, camera shake, selected-view gates, native119 owner side effect,
suppression/configuration, materials, attachment lifetime and renderer services
remain open. Lower-owner diagnostics are retained rather than replacing them
with invented success. This is not all visual-effect support.

## Validation

61 focused network/native/shared-visual checks passv3. They include original
duplicate selection, real potion packet decode/truncation, canonical state
preservation, actual binary-model one-shot retirement, body rebind without
restart, late-disposal cancellation, unsupported transform/dummy diagnostics,
and shared visual loader/control/update regressions. Initial decoded-only
model fixture could not run native impact flags1; the test now uses installed
compiled vim_heal02 instead of weakening playback to an unblended fallback.
Buildv2 passes with the existing bundle-size warning.

Isolated Electron/WebGL replayv1 uses all captured v80 game packets and actual
installed visual rules/models/textures. It routes three original healing
packets plus captured duration lights through production decode/world/visual
presentation. Result: three instants, maximum four ready visuals,768 particle
vertices, resourcesfx_light_clr/vim_heal02, natural instant retirement, and
canonical registry unchanged by every presentation delivery. Captured light
160/175 attach; lower-priority243 stays detached under native group selection.
Peak rendered PNG inspected. Replay uses synthetic target bodies/anchors and
deterministic renderer steps; it is not an original-client visual comparison
or a new live-server acceptance run. Its full diagnostics remain in JSON.

Existing installed singleplayer visual206/vce_positive cessation regression
passes: native controllers, Detonate/Explosion,150 vertices and retirement.
This checks the shared lifecycle, not a full SP campaign.

User client43328/v81 and server20964 stayed live and untouched. The new build
has not replaced that session. A reconnect/live-effects question is pending;
do not infer approval from elapsed time. Full concurrent original-client
combat/casting/effects/audio and remaining interoperability gates remain open.

Sealed backups/multiplayer-native-visual-delivery-20261018-v1.zip:13881 files/317963324 bytes. Writer39847 finished exit0, verified every entry length/SHA256, terminal handle consumed. Scope audit13882 entries including manifest,22 selected required files present,zero forbidden entries. Credential audit inherits13680 unchanged text entries from the audited item checkpoint and scans43 changed/new entries:zero candidates/new credentials. Audit and this post-seal note remain outside archive. No credentials used this turn. User client43328/server20964 untouched; reconnect-effects question still pending. Full goal remains ACTIVE.
## 2026-10-18 point-target temporary objects

The follow-up implements native point/target visual dummies. It supersedes the
earlier dummy-unsupported limitation below; beam procedural rendering remains
unsupported. Target build is the same read-only nwmain SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

Original receiver1407857f0..14078644b allocates a0x480 creature, loads c_dummy
with part255/flags0, reads the current module's area, registers an internal
object, then sets ID/area, AI membership, scene, position/desired position and
appearance201. Setter765920(1,1,lifetime) precedes temporary104=1. Ordinary
point lifetime is10000ms; extended lifetime is6000ms for zero duration or the
lowDWORD of cvttss2si(f32(duration*1000)). It retains the original source ID.

Registration has a verified native quirk: point785bde/target78616e abort on
nonzero status, but source785f9c aborts on zero status. This is visible in the
saved disassembly and confirmed by complete original receiver execution, not
just decompiler output. The source branch is preserved and diagnosed. The
adapter reclaims an allocation that cannot enter its scene; it does not leave
an orphan or claim that failed admission produced a visible effect.

inspect-native-visual-dummy.py executes the full receiver in Unicorn for240
cases: allocation, model/area admission, both registration statuses, all three
roles, duration zero/fraction/negative/DWORD wrap. Message scalar reads, empty
transform maps, ctor/model, array/module/AI/scene and fade setter are explicit
captured lower boundaries. This proves receiver arguments/order/field writes,
not those lower implementations or full native renderer behavior. Their
existing independent array/fade/expiry oracles remain regression coverage.

createClientVisualDummy projects those rules. Synchronous SP and asynchronous
network delivery share one generator route, preserving order across model I/O.
NetworkVisualPresentation borrows ClientProjectilePresentation's existing
dummy owner and ClientObjectArray: projectiles and visuals consume ONE internal
ID cursor, separate from NetworkWorld.registry. Temporary render facades use
the actual c_dummy model and appearance201; AI expiry uses the existing native
world-time/fade/removal implementation. Natural expiry, disposal and late area
loads release their visuals/models. Source abort cleanup consumes its allocated
internal ID without recycling it. No canonical object or game effect is added.

59 focused checks pass network-visual-dummy-focused-tests-v1.txt; buildv1 passes
with the existing bundle warning. These include all240 original creation cases,
9996 existing projectile/fade cases, sync routing, async ordering, real installed
c_dummy/healing models, allocator coexistence, expiry at10000ms, canonical
immutability, source-abort cleanup and late-disposal cancellation. The first
new test run failed because its fixture treated a2DA Map as an array; corrected
fixture then passesv2. Production behavior was not loosened to pass it.

Isolated Electron/WebGL replayv2 passes: all three actual captured potion
packets plus ONE explicitly synthetic decoded point packet. Actual installed
rules/c_dummy/vim_heal02 render768 particle vertices. A synthetic reserved
projectile occupies internalID0; the point dummy receives1, survives9999ms,
expires at10000ms, preserves the projectile and leaves canonical state identical.
Point PNG inspected. Real target bodies/anchors remain synthetic. This is not
a new live server test, beam support, original-client visual comparison, audio
or full scene/cache/display parity. Those limitations remain diagnosed.

User v81/PID43328 and vanilla server20964 remain untouched. New build is not
loaded in that session. The full multiplayer goal remains ACTIVE.


Point visual checkpoint SEALED: backups/multiplayer-native-point-visuals-20261018-v1.zip,13897 files/318345562 bytes. Writer51663 finished exit0, verified every entry length/SHA256, terminal handle consumed. Scope13898 entries including manifest/18 required present/0 forbidden. Incremental credential audit inherits13712 unchanged text entries from audited visual-delivery checkpoint and scans25 changed/new text:0 candidates/new credentials. This post-seal note and audit are outside the archive. New build not loaded in user v81; client43328/server20964 untouched. Full multiplayer goal ACTIVE.

SEALED effects/render/beam checkpoint: backups/multiplayer-native-effects-render-beam-20261018-v1.zip,13939 files/327498507 bytes. Writer55177 terminal exit0 consumed; every entry length/SHA256 verified. Scope13940 entries inclmanifest/28 required present/zero forbidden. Credential audit inherits13723 unchanged text entries and scans49 changed/new text:zero candidates/new credentials, against audited point-visual baseline. This post-seal note/audit are outside the archive. v84/PID39408 remains OPEN on server20964; automated inputs completed, current user session must stay untouched. Beam/reference build not loaded; live shader/HUD fix and visible potion test verified. Full multiplayer goal ACTIVE.
