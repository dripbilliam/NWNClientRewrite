# Client pause messages and creature presentation clocks

Read-only target: NWN:EE89.8193.37-17 x64
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Previous goal turn was concrete progress: native Time Stop lifecycle, installed
casting and verified1945-test backup. This increment connects the client side;
full spells/combat/campaign acceptance remains OPEN and goal ACTIVE.

## Original dispatch and ownership

Named pause searches did not identify a client receiver. Existing major
dispatcher7a41a0 and its current REA capture prove major3 routes to7a4d30;
that owner's case9 calls7a5680. REA dossiers `rea-client-pause-*.json`,
`rea-client-major-message-dispatch.json` and
`rea-client-module-message-dispatch.json` retain native ranges/calls. This is
read-only research; no original game/Ghidra changes.

| Owner | Address | Observed rules |
| --- | --- | --- |
| Server pause notification | `1404dd0c0` | Write2-bit BYTE, BOOL, WORD count, all active-exclusion OBJECTIDs. Only load-state2 players receive major3/minor9. |
| Active server list | `14055f080` | Bit2 selects100f8, else bit1 selects10100, else null. Wrapper55b2a0 forwards here. |
| Client receiver | `1407a5680` | Allocate16-byte owned list, read BYTE(2,1)/BOOL/WORD(16), then count OBJECTIDs with16/doubling storage. Check overflow after all reads. Apply state only without overflow; refresh existing GUI owner when A8 is nonnull. |
| Client state wrapper/internal | `1406acc40` / `1406e1fc0` | Separate client flags4c8 and world50/TimeStop58/pause60 timer pointers. Initial comparison is raw(flags&mask)==value, not Boolean. |
| Clear old exclusions | `1406d6770` | POST-transition flags/timers with OLD list select each object's reset time. Reset virtual10 precedes scene virtual158; live count re-read. Then free/clear old buffer. |
| Active client timer | `1406d7fe0` | INVALID selects world; bit2 priority; otherwise bit1. Null shared list admits any ID, present list requires membership. |
| Client exclusion query | `1406dab20` | Null list returns1; otherwise exact ID search. |
| Creature reset virtual10 | `140807680` | Write only day50/time54. Base CGameObject2964d0 reset is a no-op. |

Incoming client IDs are the external namespace from WriteOBJECTIDServer4763e0.
This code never rewrites canonical server object IDs. The client has ONE current
received exclusion list, not the two separate authoritative server lists.

Turning on pauses/snapshots world twice. New bit2 also pauses/snapshots timer1
twice and emits manual-pause message code205. Clearing mask2 resets timer2 from
timer1, snapshots/synchronizes counters, resumes world only for the native flag
condition, then resumes timers1/2 and emits code206. Clearing mask1 resets both
auxiliary clocks from world and resumes all three. Audio and GUI lower callbacks
retain their original order. Only raw value1 selects ON; GUI set/clear later uses
nonzero vs0. Repeated mask2/value1 still executes because2!=1.

After timer changes, clear/reset prior exclusions, then append unique received
IDs. Duplicates are not appended but still perform per-ID object/model/reset
work. Incoming scene virtual150 precedes active-time reset. The normal state
owner consumes and frees its incoming list. Receiver overflow and a state no-op
leave allocation unconsumed in native code; the JS DTO records this condition and
uses garbage collection rather than intentionally leaking heap allocations.

GUI pause input blocking also checks active pause bits, profile mode!=1 and the
controlled object's exclusion membership. GUI flag bits are2 for mask1 and4 for
mask2. Complete GUI widgets, manual-pause text formatting and audio internals are
still lower providers, not inferred implementations.

## Animation clock provenance

Wrapper6ab840 leads to the active client timer. Its caller7fbd10 is the creature
AIUpdate owner: the block7fbfb8..7fc01d reads active time, subtracts previous50/54,
and stores the millisecond remainder in58. It does not combine whole elapsed
days. A later active-time query at7fc1f2 writes fresh50/54.

Creature vtable location is proven from AIUpdate's data reference at e475d0.
Backward scanning reaches the RTTI boundary and actual table e474e8; AIUpdate is
slotE8, reset10 is807680, cast18 is762820. An earlier candidate guessed AIUpdate's
slot position and selected802cc0, which analysis identified as LoadModel; that
candidate was rejected and retained. See table-v2 metadata and
`rea-client-creature-pause-reset-time-v2.json` for the corrected reset.

Nested replacement of excluded IDs can leave an object's reset stamp ahead of
its newly selected clock. Native SubtractWorldTimes then leaves outputs
unwritten; the caller nevertheless copies its scratch into elapsed58. Original
bounded execution with explicit seeds demonstrates this. The local renderer
logs `client.pause-clock-undefined`, retains its current pose time and rebases
its mirror's stamp, so later valid frames resume. This is an explicit local
undefined-output recovery policy, not claimed deterministic native stack parity.

## Live implementation

`client_pause.js` ports receiver/state/clear/selection decisions with explicit
lower providers. `ClientPausePresentation` owns three WorldTimers and client
external object mirrors. It snapshots the server's selected exclusion IDs at
send time, narrows decoded scalar fields, and processes owned local deliveries.
`ModuleSession` now includes those canonical IDs in its typed local notification;
the client projection converts their namespace. Native raw packet framing,
load-state transport filtering and complete wire serialization are not claimed.

The renderer uses per-creature accumulated client elapsed time, which preserves
clip phase across clock rebasing. `CreatureAnimationPresentation` schedules
attacker and target cues against their own clocks; stale/unbound target cues
cannot request a missing creature clock. Ordinary actors stop sampling later
clip poses while excluded actors advance. The authoritative registry, world
positions/actions, RNG and IDs remain untouched by presentation.

Known lower adapter omissions remain recorded: scene virtual150/158, audio
suspend/resume, manual-pause GUI/text, other object reset overrides. Pause
creature mirrors are a local presentation projection; unifying every client
object/scene owner and applying clocks to all projectile/particle/looping visual
paths remains separate work. No complete pause presentation claim is made.

The server's undefined GUI queue-clock fallback is unchanged. Its identified
per-frame polling now uses existing diagnostic aggregation, keyed by canonical
actor reference and unresolved previous stamp/status. First clock sample is
labeled, all occurrence counts/first/last timestamps survive flush, and new
unresolved stamps produce new groups. This does not suppress engine calls,
script errors or resource failures.

## Validation and retained failures

Original-code `inspect-native-client-pause.py`, capturev5:759 cases:
295state,12clear,32timer,32excluded,384receiver,4reset. Complete owners and
ResetTimer/GetSnapshotTime execute. Pause/snapshot/unpause/time output, scalar
codec, allocation/arrays, object lookup/casts and scene/audio/GUI services are
captured boundaries; Tracy disabled. Synthetic duplicate/missing IDs, flags,
raw values, null getter lists, GUI/profile/audio gates, ownership and capacity
growth are covered. Receiver tests isolate its apply boundary; runtime tests
compose the state owner. Allocation failure/raw bitstream/GPU are not covered.

`inspect-native-client-creature-clock.py`:90 bounded caller/Subtract cases,
including day/remainder behavior and seeded unwritten output. Full AI prologue,
caller stack history and model rendering are outside that oracle. Accepted native
tests compare all849cases. Initial oracle failures were captured array allocation
after clearing, an undersized ResetTimer range, a metadata filename typo and scalar
reader ABI assertions; fixed in v5, original failure logs retained.

Real-session tests cover independent client/server clocks, nested mask1/2 changes,
replacement exclusion IDs, canonical object references/cursor and explicit
undefined-clock recovery. Real ModelAnimator sampling freezes ordinary pose0.25
while the caster advances to0.75, then resumes at0.35/0.85 without a phase jump.
Raw message count wrapping and immutable ID snapshots are tested. Diagnostic
aggregation tests retain all repeated occurrences. Initial tests exposed an
incorrect subtraction result property in the new port (fixed to native time
remainder), then the real native undefined branch. The model fixture initially
had no stats/client recipient; corrected that fixture rather than inventing
delivery. Those failure logs remain.

Full suite `client-pause-full-tests-v2.txt`:1953PASS, terminal0. Buildv2PASS with
existing bundle-size warning. Focusedv6 passed25 tests before the final unbound
reaction regression; fullv2 covers that additional case.

Installed TimeStopv5 PASS4 checks: ordinary authored Time Stop and slot use,
decoded pause delivery into independent client timers/mirrors, Light casting
while time is stopped, strict natural expiry/world restoration/deferred drain.
Canonical references/cursor unchanged. Ten warning records retain193trap polling
occurrences,2server pause limits,2audio adapter limits and71undefined queue polls
in2records. Startup/general AI traversal isolated; real individual native player/
NPC frames and the prior high-level in-memory BIC fixture run. Installed nested
server-pause/player-framev5 also PASS4 checks, including received ID snapshots,
real stat dirty-cache update and queue recovery.

Electron TimeStop UIv1 PASS: full native AI, real prepared spellbook/hotbar drag,
right-click Cast spell/Wizard/Levels7–9/Time Stop, original NCS, slot use and
natural expiry. Actual NPC19 pause1 clip time remains1.033 across251ms while
client timer1 advances1563249→1563500 and world stays1563133; client flags return0.
No console/new errors. Known lifecycle/trap/scene/particle/presentation warnings
remain. Its21undefined queue polls are retained in2records. Startup/entry and
high-level BIC are explicit fixtures, not campaign acceptance. Final rebuilt UI
TimeStopv2 PASS terminal0: NPC19 pause1 stays1.009 across250ms,
world1563109 unchanged, client timer1 advances1563291→1563541, flags return0.
Final normal casting UIv2 PASS terminal0: spellbook/self radial, slot use,
F2 target/cancel, casting animations and world radial Counterspell target22.
No console/new runtime errors in either accepted capture. All validation process
handles consumed; REA99283 remains live and idle.

## Remaining acceptance gates

Complete scene virtuals, GUI/audio, non-creature resets and all visual clocks;
generic ApplyEffect bookkeeping and saved active effects; remaining57unbound
engine calls/22missing impact scripts from auditv52; complete combat and campaign
playthrough. Binding presence is not branch completion. No spell/campaign
outcome was hardcoded. Single-player remains the priority; goal stays ACTIVE.

Verified checkpoint: `backups/client-pause-clocks-1953-20261017-v1.zip`,
10518files/142972273bytes. Every archived length/SHA256 verified;
session88281 terminal exit0 consumed. Verification note added after sealing.
