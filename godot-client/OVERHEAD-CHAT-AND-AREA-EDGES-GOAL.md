# Overhead chat and native area edges

Requested 2026-11-04, after the level-up menu flash fix. **Active; completion is
unproven.** The earlier complete level-up/UI migration remains unfinished and
tracked in `NATIVE-LEVEL-UP-PARITY-GOAL.md`, `NATIVE-UI-PARITY-GOAL.md`,
`NATIVE-UI-RESOURCE-INVENTORY.md`, `NATIVE-UI-FRAMEWORK.md` and
`CLIENT-PARITY-RESUMPTION-GOAL.md`.

1. Finish the reported old-menu flash. Native Class presentation must appear
   immediately while real server choices are pending. It remains cancellable
   and cannot fabricate choices, a server token or an HP roll. The current
   source passes isolated opening/routing/control checks. The previous visible
   client has since been closed by the user; no replacement was auto-launched.
2. Implement native Godot overhead speech/chat using the received event and
   speaker/entity owners. Match original channel/display rules, formatting,
   readable placement, wrapping, queue/lifetime behavior, camera anchoring and
   visibility. Keep ordinary chat, combat floating feedback and server floaty
   text distinct where the original does. Reuse authoritative identities and
   current resource/text owners; old connections, areas and entity incarnations
   must not attach text to a replacement object. Work is event-driven with
   projection over active speakers only.
3. After chat works, investigate the original binary's scenery beyond the
   active/playable region. Determine the relevant sky/background, fog,
   tileset/edge geometry, visibility and streaming behavior from evidence.
   Implement the missing native behavior with the original assets and verify
   the result against native/reference/local or sealed-capture cases.

The completion evidence must include meaningful current native control/event
tests, stale/lifecycle cases, current source integration, owned local-server or
recorded received-data cases, and actual visual review. Pure helper counts do
not establish visual or native-client parity. Keep limitations explicit.

Preserve the user's processes, focus, pointer and session. No automated
public-server world/chat/joins, shared native rebuilds
or GPU/performance benchmarks. Use isolated candidates for unrelated work until
it can be reviewed and promoted safely. All rendering stays native Godot.

Current ownership: root handles shared integration and preserves user processes;
`entity_api` owns received-event provenance and the new border stream;
`native_ui_parity` owns speech views/rules and independent integration review;
`character_picker` owns original popup/border research and pure border plans.

Current milestone: ordinary speech is integrated with native rules, actual
fonts/popup resources, explicit source/context lifetime provenance, early
Gameplay dispatch and shared hover-popup arbitration. Recorded native packet,
headless control/lifecycle, shared-registry and original overlap arithmetic
checks pass; live visual acceptance remains separately tracked in
`NATIVE-OVERHEAD-SPEECH.md` and receipts. No live world/rendering claim is made.
The missing native `LoadBorder` path is now integrated using original
`<tileset>_Edge.2da` models, proven border plans and optional worker-backed
streaming after player admission. Current headless World/stream lifecycle,
installed model decoding and settings checks pass; see `NATIVE-AREA-BORDER.md`.
No graphical/GPU/live-server validation was performed for this addition.
Ordinary speech is distinct from combat numbers and server-script prompts.
The new [ScriptFloating owner](NATIVE-SCRIPT-FLOATING.md) now replaces the
legacy93/94 widget path with the native per-creature400ms FIFO, independent
1.5s GUI lifetimes, source-pose anchoring, remapped TTF17, native colour commands
and optional one-time mask128 chat echo. Original binary evidence, asynchronous
resource/orphan cases, scope checks and actual original-server received packets
are retained. Full combat/script shared-queue and visual parity remain gaps.
The complete goal and earlier level-up backlog remain unfinished.

Continuation audit: the previous turn made progress (integrated ScriptFloating,
native parser correction and the original-local-server v3 packet/layout proof).
This continuation also made progress. The v4 follow-up verifies actual Root
camera-anchor publication and Canvas visibility on two real frames per event.
The new real-border geometry gate passes992 checks through production
Loader/Assets/Pool/Template, including all four rotations, source vertices and
bounds, shared resources, decorative isolation and scoped retirement.

The native common log tail revealed an additional correction: a chat echo
belongs to its admitted connection, independently of widget area admission.
A single text receipt now serves both consumers, retaining receipt-time text
and custom tokens across an area transition. The explicit accepted transport
path bypasses unrelated rule jobs while keeping widget scope checks and legacy
callers separate. Current echo24, widget51, composed196 and projection/JSON13
checks pass. The original-local-server v5 run on that final path captures four
real93/94 packets/deliveries, eight real-frame paints and two requested echoes;
all source/lifetime, ACK, worker-drain and preservation guards pass. Current
feature sources (33 files) match that accepted run. Scope24, ordinary speech139,
frame1157, anchor22 and prior border gates remain separate overlapping scopes,
not an aggregate parity score. Earlier rejected evidence is preserved.

The current combined checkpoint is
`reports/native-overhead-and-area-border-integration-v3.json`.
Headless camera publication/Canvas visibility and actual model construction do
not establish raster pixels, native screenshot parity, movement or FPS. The
border publication time limit is soft; an indivisible model unit can exceed it.

The GUI-up rounding correction and native closing-token correction have their
own receipts. Protected editor25060 and server7568 remain running; only the
owned test server/client were started and cleaned up. No public connection,
shared native rebuild, focus change or GPU benchmark was made. A graphical-
availability question remains pending; no answer is assumed. The goal stays
active for visual acceptance and the documented limitations, without replacing
the unfinished level-up/UI/gameplay goals.

Further completion audit found concrete unfinished work beyond pixels:

- Ordinary speech now has its own original-server/head-anchor/registry proof,
  `reports/native-ordinary-speech-received-acceptance-v1.json`. Two real Talk
  packets exercised actual head/font/Bubble/registry publication, same-view
  replacement and expiry, separately from ScriptFloating. It uses explicit
  mode1/font14 and does not certify native effective settings or raster pixels.
- The unbound Godot popup settings reader uses pre-settings mode1/largefalse.
  Original registered settings, and both current original user profiles, use
  `ui.text-bubble-mode=2` and `ui.large-font=true`. Native mode/font callbacks
  also update existing popups. Their persisted owner and hot behavior must be
  wired from source-backed rules rather than declaring the defaults equivalent.
- Original ParseStr has no automatic raw-colour-tag passthrough. The generic
  Godot formatter currently has one for already formatted UI input. Certified
  native parse call sites need a scoped correction without breaking legacy
  literal descriptions. Ordinary escaped override handling and true retained
  global context remain distinct.
- The original special object-clock selector is being mapped against actual
  received timing owners; the nominal adapter alone does not prove it.

These are active audit findings, not accepted changes or proof of a live
failure. New local speech-test hooks are isolated and opt-in; original inputs
and existing source seals remain preserved.

The following continuation made concrete progress on those findings. The strict
native parser matches856 defined original outputs and261 hash cases, retaining12
heap-dependent unterminated cases as unsupported. Script93 now uses that entry;
Script94 remains literal and legacy rich-description resolve is unchanged. The
ordinary receipt stages and separate log/overhead copies are integrated and under
focused regression checks. A source review additionally distinguished initial
wire/fetch gender from the explicit receiver's context-gender getter; missing
creature gender is not fabricated.

Popup preferences now have native canonical keys/defaults and46 passing isolated
actual-control/persistence checks. Live reader/hot-change integration is a separate
active slice. The unchanged original hot-change oracle passes80 mode and12 font
cases, plus7 independent receipt checks. Current raw caption byte conservation is
source-proven; mode changes reset timers/refit all constructed popups, whereas
font-only changes preserve timer AND shape choice. Do not promote the preference
controls alone as complete hot behavior. The prior combinedv3 receipt is a
historical source-pinned checkpoint, not a claim that every subsequent source is
identical to its inputs. No graphical availability answer is assumed.

The accepted next checkpoint is
`reports/native-overhead-native-methods-checkpoint-v2.json`: ordinary receipt29,
received75-packet/HUD140, ordinary policy/font/resource140, preferences46,
strict parser3769, ScriptFloating-widget51 and echo24 remain separate scopes.
The native TLK pair loader's missing-female file alias is now explicit at the
actual Gameplay load/publication boundary; malformed or pending files do not
become aliases. The broader receipt check found and corrected actual owner-scope
normalization before context snapshot capture. Script93's top-level native fetch
edge is also closed, with94 still literal and legacy resolver unchanged.
Hot popup settings/caption lifecycle work remains active in its own coordinated
atom; visual acceptance and remote special-clock/retained-model limits remain.

## Native-method integration continuation

The next integration closes the settings/caption atom above. The actual
ChatPreferences owner is bound before speech; canonical native mode2 and
large-font true reach Gameplay, Owner and Registry. Constructed popups share one
Registry caption/GUI clock. Mode changes refit current raw bytes and reset the
native timed flag, font-only changes preserve wraps/bounds/timers, cache writes
do not replace active speech, and expiry uses the traced native ToggleOff
default. Unsupported CR-relative restoration stays explicitly unknown.

Review found and fixed two actual scheduling defects: delayed receipt adoption
could consume one frame's elapsed time twice, and an Off-to-On popup waiting for
its model had no wake event. A frame-accounting marker now prevents double
charging; actual Root instance publication wakes a scoped pending popup without
idle polling. Admitted hover now uses the same native head projection with one
rounding step and no viewport/AABB fallback. Ready identity world items use the
native .5 world-height rule, separately from Actor creature-height metadata;
nonidentity item controller sampling remains unavailable.

The common chat-body audit also corrected literal channels and log-only12/15.
A failed current TLK-family load can no longer republish retained previous
tables as current. The unchanged loader fixture detects both stale exposures
against the preserved before snapshot and passes all20 checks after the fix.

Current copied/headless checks pass: received/HUD140, body receipts29,
literal/log38, TLK publication20, settings34, delayed/visual handoff17,
item anchor30 and actual native hover25. They retain exact source/copy/native
output guards. Their counts are separate overlapping scopes, not a parity score.

The sole authorized current original-local-server run also passed on
127.0.0.1:5129. It received two actual Talk packets through the real model-head,
font/Bubble/Registry path; all15 ordinary checks establish fresh native
mode2/font16 defaults, same popup/ordinal replacement, one shared clock and
natural expiry. The separate inherited ScriptFloating gates remain intact.
The owned server/client exited, private lease released, six native outputs and
encrypted profiles unchanged, and all protected process identities (including
server7568/editor25060) preserved. No public world, visible launch, focus/mouse
action, shared build, pixel comparison or GPU benchmark occurred.

The earlier checkpoints and failed attempts remain unchanged historical
evidence. Visual availability is still unanswered; no elapsed time or automatic
goal continuation is treated as permission. Manual native visual acceptance,
remote special clocks, retained-model removal fade and documented unmatched
parser/name-prefix providers remain limitations. Keep this goal and the broader
level-up/UI/gameplay goals unfinished.

The immediately preceding immutable checkpoint is
`reports/native-overhead-native-methods-checkpoint-v3.json` (SHA256
`371ee2efd4d9d3261756953d34ce95025f1bcbca8bac48cc6a85df0e74bd449d`).
It verifies all ten selected isolated proof inventories still match current
sources and separately pins the original-local-server acceptance. The accepted
run's bounded source/evidence snapshot is retained at
`.cache/ordinary-speech-current-acceptance/sealed-v1`, excluding credentials,
user profiles, server secrets/databases and engine/server binaries.

## Current header and atmosphere continuation

This turn made concrete progress. The scenery audit identified a same-area
atmosphere gap: module-time updates were retained by the protocol owner but never
published to the existing environment after entry. The Root now publishes a
compact authored atmosphere at accepted full/delta snapshot boundaries, with a
single owner-scope witness. Unchanged/calendar/wind-only headers do not reset the
phase clock; new phases use received transition milliseconds, while authored
field/duration changes carry live elapsed. Actual Root/Session/Environment35
checks pass. The border geometry97 pins remain unchanged; no new culling defect
was inferred from missing pixels or an unported native collapse optimization.

The native header audit also proved exact remote-name spacing and gender0,
parseFlag0 prefix fetches. The new detached header receipt is integrated for
prefixes and explicit remote wire names at the body receipt boundary, preserving
the existing bounded queue. Base labels remain raw; only overrides parse, without
a controlled-actor context. Current Gameplay/Chat33, body38, receipt29 and
received/HUD140 checks pass. Earlier fixture-only rejects are retained; no
assertions were removed to obtain the accepted gates.

The final sole localhost5129 original-server check passes ordinary15/capture9
and the separate inherited ScriptFloating gates. It accepts the actual fixed-day
atmosphere header with source.elapsed0 and a separately advancing live elapsed,
without resetting on subsequent headers. All source/module/output/profile and
protected-process guards pass; the owned server/client stopped and ALT lease
released. This run does not exercise all prefix/remote cases, server phase
changes, sky geometry, native pixels, movement or FPS. The verified incremental
snapshot references1,661 immutable base inputs and copies only four new/changed
text inputs; no credentials, profiles, secrets, databases or binaries are copied.

The current immutable checkpoint is
`reports/native-overhead-native-methods-checkpoint-v4.json` (SHA256
`470fe8c77126022462996086667146587e3d26e8a6761d6682440882f0a97a15`).
It explicitly distinguishes the atmosphere test's pre-Header imported Gameplay
pin from the unchanged tested Root/Environment code, current full graph and
current real-server initial-atmosphere acceptance.

Completion remains unproven. Canonical local actor stored names still use the
old adapter: P actor-name writes and U party labels are different, and native
stats+40 requires actual constructor/retained-state ownership. The next hook
belongs at accepted native-type5 construction/reuse commit, not renderer nodes,
first-seen snapshots, generic data-proxy creation or lifetime-token guessing.
Visual availability remains unanswered, and level-up flash acceptance, special
object clocks, retained-model fade and other documented limitations remain.
Keep this goal and all referenced broader UI/gameplay/migration goals active.

## Stored actor-name integration checkpoint

This continuation made concrete progress on the commit hook above. Private
`NetworkWorld` metadata now distinguishes a tracked fresh type5 A from retained
or unknown owners, stages P/D changes with the canonical transaction, and keeps
incomplete history sticky until reset. Native constructor-empty first/last and
override slots are certified only at that boundary. P actor names and U party
labels remain separate; ambiguous delayed D+A does not invent a new owner.

Godot now owns the stored strings and captured lookup receipts. Actual chat
events carry their exact private name state before raw snapshots coalesce;
queued speech cannot acquire a later name, CUSTOM value or live override.
Explicit successful empty names retain the native separator in both painters.
Generic/imported/BIC-loaded state with unknown prior DisplayName remains on the
uncertified compatibility path. The independent implementation review found no
new material defect within the certified scope.

Current focused gates pass World51, Actor65 and actual Gameplay122; maintained
Header24/37, body38, received/HUD140, parser3769 and Script51 regressions pass.
All their imported inputs still match at this checkpoint. The earlier
atmosphere35 proof has four explicitly listed imported UI/text changes; its
tested Root/Environment implementation is unchanged. Border geometry992/97
remains exact. Counts overlap and are not a parity percentage.

The sole current original-local-server run passes ordinary15/capture9 and the
unchanged inherited Script16/10/9 gates. Both actual Talk rows used the native
stored character name with `nativeNameResolved:true`. This is evidence for the
tested common controlled flow, not all BIC/GFF ownership. All1,664 source pins,
six native outputs, two encrypted profiles and15 protected process identities
were preserved; the owned server/client exited and the ALT lease was released.
The verified incremental snapshot uses1,652 recursive base references and only
12 changed text copies, with no credential/profile/database/binary copies.

The immutable current checkpoint is
`reports/native-overhead-native-methods-checkpoint-v5.json` (SHA256
`6e4d46692cdaf6b62cbbc7d36f700e7cc221fc28c2e9299ddc77ebef69697920`).
See [the integration contract](NATIVE-ACTOR-NAME-INTEGRATION.md) and
[current original-local acceptance](NATIVE-ORDINARY-SPEECH-ACTOR-NAMES-ACCEPTANCE.md).
Visual availability remains unanswered; no visible launch, GPU/FPS test,
public-world connection, shared native rebuild or user-process action occurred.
The level-up flash, manual visual acceptance, special clocks, retained-model
fade and other disclosed limits keep this goal unfinished. A separate bounded
follow-up now targets the existing name-only model-signature invalidation; this
checkpoint does not claim that optimization is implemented or measured.

## Native name-update model boundary

The bounded follow-up is now implemented. Original P400 writes stored names
and refreshes popups without setting the model-change byte. Godot's signature
had included that field and unnecessarily invalidated installed, in-flight and
failed model bindings. Its private creature-only projection now excludes the
name while retaining the received row for current state/name consumers. Genuine
appearance/equipment changes and opaque non-creature tuples keep their existing
behavior. The exact dirty source was backed up before changing it.

The focused actual World/update/preparation test reproduced 12 failures out of
63 before the correction. All 63 assertions then passed; the final candidate
also passes nine additional null/scalar/array compatibility cases, for 72 total.
All 197 source/copy pins, six native outputs and the engine remained unchanged
during that final check, and its owned child closed. This is CPU behavior and
scheduling evidence, not measured FPS, original asset publication or pixels.

The immutable follow-up checkpoint is
`reports/native-overhead-native-methods-checkpoint-v6.json` (SHA256
`ecd3311a64a6e1068f75e1e1fddedfdf04707a2fa8ff2ef2c255c57b0e32f91f`).
It retains v5 as historical evidence before this single production-file change
and lists exact imported-source drift for every parent proof. The original
local-server run was not repeated or presented as testing the later model-key
correction. The final dedicated gate compiles and checks the current owner.

A bounded original-clock review reconfirms that remote ScriptFloating special
clocks require missing connection-owned major3/minor9 pause/list/timer history
and lifetime-bound object reset stamps. The current nominal delta is not
promoted as equivalent. No safe isolated widget substitution was made.
Graphical availability remains unanswered. Manual visual acceptance, level-up
flash acceptance and all previously disclosed native-parity gaps keep the goal
active; no public world, visible launch, GPU benchmark or user-process action
occurred in this continuation.

## Remote native clock port

This continuation makes concrete progress on the special-clock gap. The actual
remote decoder now admits major3/minor9 into detached native mask/BOOL/WORD/ID
fields. Repeated transitions, duplicate IDs and namespace bits survive the real
NetworkGameSession delivery chain; malformed packets cannot publish partial
state or send gameplay commands. Decoded recordings now retain this kind.
The focused helper, actual session/capture and existing session checks pass
53 tests with 126 unchanged source pins. Original overflow-only handling and
the decoder's stricter unread-data rejection remain explicitly distinguished.

New standalone native Godot timer and pause-selector components pass 7,242
checks against 759 retained native pause, 90 creature-clock and 55 seconds
cases plus authored arithmetic/unknown-state coverage. Unsigned counters use
exact DWORD limbs; backwards native unwritten outputs remain unavailable.
The final gate compares native FLOAT bits exactly. Earlier parser/fixture
representation failures are retained; no tolerance or algorithm weakening was
used. All 16 source/copy pins, fixture, engine and six native outputs stayed
unchanged during the accepted check, and the owned child exited.

The original lifecycle audit proves that the three clocks are process services,
module3/1 changes only T0's rate, and cleanup has ordered pause-clear/reset work.
Creature birth uses base T0; frame snapshots precede packets and GUI T2 time
follows object updates. The native counter is absolute QPC-derived or DWORD
GetTickCount microseconds. Godot's ordinary process-relative ticks cannot be
silently substituted after rate changes. An isolated direct-Real Windows
provider candidate is being prepared; it is not built or selected by this
checkpoint and does not claim default threaded-cache sample-phase parity.

The immutable checkpoint is
`reports/native-overhead-native-methods-checkpoint-v7.json` (SHA256
`9b7abc197cfc561ee2b1831940c24561932174e36b195b89d6c27b85e94d5d46`).
The components remain unimported pending ordered early ingress, source-lifetime
stamps, process cleanup and GUI-clock integration. Nominal ScriptFloating time
has not been relabeled as native special-clock behavior. The
[remote clock contract](NATIVE-REMOTE-CLIENT-CLOCKS.md),
[component acceptance](NATIVE-REMOTE-CLIENT-CLOCK-COMPONENT-ACCEPTANCE.md) and
[lifecycle audit](NATIVE-REMOTE-CLIENT-CLOCK-LIFECYCLE.md) preserve those scopes.
The full goal stays active. No graphical permission is inferred, and no public
world connection, visible client, GPU test, shared native rebuild or user-process
action occurred.

## Absolute clock source and current visual permission

This continuation made concrete progress beyond checkpoint v7. Independent
review found a full-DWORD restored-timer normalization edge. The native loop
was corrected algebraically for its full admitted domain in constant time,
with 340 separately labeled literal-loop reference cases. Exact unsigned
provider limbs now enter the timer directly, with atomic unavailable-input
handling and mutation isolation. All 7,974 component checks pass, retaining
the previous corpus and assertions.

An isolated new Windows C-ABI clock candidate was compiled only into its own
private directory. It implements the native direct-Real conversion and cached
configuration/divisors, with explicit missing-data metadata. Its 663-check
private headless gate samples real Windows QPC. An independent original-code
oracle then executed the native constructor prefix and Real getter under
controlled APIs: the actual candidate matches 11 configurations and all 113
defined unsigned results exactly in a separate 1,484-check comparison. Four
native unwritten-QPC failures stay unavailable. The physical FP exception-status
and default timer-thread sample phase are not claimed.

A further 85-check private integration injects actual DLL samples into three
actual Godot timers and composes conditional snapshots and nested pause/reset
order. The main project does not import these clocks or install the candidate
descriptor yet. Ordered early ingress, lifetime-bound object stamps, actual
GUI-clock ownership and cleanup still need their complete runtime path. This
work has not relabeled nominal ScriptFloating time as native parity. Shared
native outputs, profiles and existing processes remain preserved.

Current immutable checkpoint:
`reports/native-overhead-native-methods-checkpoint-v8.json` (SHA256
`e7e377d124d34f97638d96803693ba96ab865225fbc0ae79423c4566cf63f60e`).
Its component, source, original-instruction and private-composition evidence
scopes stay separate; counts are not a parity percentage.

The user has now answered that the PC is available for a short **local visual
check of chat bubbles and area borders**. That lifts the earlier unanswered
visual-availability constraint for this check; it does not authorize public
worlds, user-process restarts or performance benchmarks. Root is preparing a
distinct owned graphical route, preserving every existing strict headless
check. The launch must use a secondary monitor without startup focus or mouse
capture. The full goal and all referenced broader requirements remain active.

## Local graphical observation and clock staging checkpoint v9

The owned original-local graphical run completed its 120-second lifecycle and
cleaned up its server. Actual state observations include one retained, visible
ordinary speech popup through expiry and all 300 planned decorative border tiles.
Computer Use stopped on physical Escape before active-speech/perimeter pixel
acceptance; no further visible or input work followed. Original comparison,
readability, camera traversal and performance are not accepted by this run.

New metadata accurately separates a stimulus-free observation probe from
automated admission and unknown session-input provenance. The historical run
is unchanged. Static metadata checks pass 5/5 and PowerShell AST parsing is clean.
The ordered clock-ingress helper passes 15 Node tests; the lazy per-object AI
stamp component passes 786 headless assertions, separately retaining 90 native
caller cases and 48 authored eager frames/89 lazy queries. Neither component is
activated by the main client. Original construction evidence excludes the
internal-BIC-preview alias hypothesis at inspected boundaries while retaining
strict uncertainty for external typed-owner history and ambiguous D+A reuse.

See [current status and remaining integration](NATIVE-OVERHEAD-CURRENT-STATUS.md)
and `reports/native-overhead-native-methods-checkpoint-v9.json`. The goal remains
active; clocks/GUI ownership, retained-deletion behavior, full visual acceptance
and the broader level-up/UI requirements remain unfinished. Test counts are
not a native parity percentage or an FPS claim.
