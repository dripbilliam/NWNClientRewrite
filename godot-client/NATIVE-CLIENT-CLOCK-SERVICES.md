# Explicit client clock services

`native_data/client_clock_services.gd` is a process-service
composition of WorldTimer, ClientPauseState and ClientObjectClocks. It has no
Node/process loop, counter implementation, wall-clock substitution, world row
store, renderer or runtime hooks. The injected absolute microsecond reader
returns a nonnegative integer or exact unsigned64 `{hi,lo}`. No Godot ticks or
calendar state can initialize it implicitly.

The isolated component receipts below describe their historical copied gates.
Main Session now imports the optional Runtime with its flag default off. The
reviewed DLL was staged into a new hidden main directory only after Runtime233
was sealed, without a compiler, extension-list or default switch. Root owns the
current Runtime/install/goal status; these component proofs do not imply native
pause lower-provider or live visual acceptance.

`construct_process(reader,ownerFacts,providers={},resourceLimits={})` requires
explicit `processConstructionKnown:true`. That certifies actual process/client
service construction, not a new connection, area, proxy or first snapshot. It
constructs T0/T1/T2 sequentially with their independent samples and certified
client flags0/present-empty exclusion list. Duplicate construction rejects without
sampling. Initial GUI/profile/control remain unknown unless supplied as
`gui:{known:true,value:<owner|null>}`, `profileMode`, `controlledId`.
`publish_owner_facts` updates these explicit lower owners without resetting
flags/list/timers. No live owners or callbacks appear in diagnostic state views.

`attach_connection(connection)` creates a strictly newer transport serial owner;
it never reconstructs timers or repeats a prefix, including when the first begin
arrives inside an already open receive phase. `set_scope([connection,generation,areaId],transfers,
fact)` configures or explicitly transfers only thin object clock bindings. Exact
same-physical continuous transfers follow the ObjectClocks contract. Process
timers and pause state survive areas/connections. A normal no-pause path needs no
scene/audio callbacks; it can deliver known GUI and object clock deltas.

For a non-noop pause operation the complete trusted native lower table is
required: `object(id)`, `asObject(object)`, `scene(object)`,
`sceneVirtual(scene,offset)`, `resetObjectTimes(object,day,time)`, `pauseText(id)`
and `audio(on)`. A non-null GUI additionally requires `guiActive`, `guiBlocked`,
`guiSetFlags`, `guiClearFlags`. Known absent object/cast/scene pointers return
null from a trusted provider; unknown must return `{ready:false}`. Missing
providers do not become no-ops. A failing callback yields explicit partial state
and clock uncertainty; already sampled absolute counters are not rolled back.

`resetObjectTimes` must perform/certify the actual native dispatch and return
`{ready:true,baseNoop:true}` for the proven base virtual no-op or
`{ready:true,creatureReference:ref}` for actual creature807680. A known creature
whose physical reference is unavailable may return
`{ready:true,unboundCreature:true}`; only that object's clock is blocked. It is
not evidence that a pause/rate packet was missed. Scene150/158 or unknown dispatch
semantics remain unsupported, rather than fabricated callbacks.

Frame order is explicit:

1. `begin_frame(frame)` executes PauseState's snapshot prefix **before** receive:
   T0 iff flags&3==0, T1 iff flags&2==0, T2 always. No async continuation may begin
   another prefix for that frame.
2. `receive_clock(dto)` accepts the current connection's exact
   `native-clock-protocol` version1 envelope with contiguous serial, coverage
   history and detached event. `begin` establishes transport coverage, never
   timers. Module-info changes **T0 rate only**, without rebasing offsets.
   Module-time/area boundaries do not reset clocks. Object-control validates the
   actual ingress `playerId`, `objectId`, `sourceMajor` and `sourceMinor`. Only
  5/2 changes local controlled ID;14/14 is a roster acknowledgement without a
   local-control change. Unsupported source pairs or missing/malformed IDs are
   rejected before changing control. No object is constructed by this event.
   Pause facts delegate the native flag/list/order algorithm. Native incoming
   no-op ownership is exposed as detached `unconsumedIncoming`, not reinterpreted
   as successful consumption.
3. Synchronous trusted constructor/reset calls capture exact current pairs.
   Resets are staged as detached references/pairs/frame/order only. There is no
   callback replay after receive.
4. `finish_ai(frame,{module,area,completePass})` samples **final post-receive**
   three pairs/selector/day length, begins ObjectClocks, replays staged scalar
   reset records, and completes conceptual AI. The caller must own the actual
   all-registered AI eligibility/completeness fact; model/picking readiness is
   unrelated. No per-world frame scan occurs.
5. `object_delta(ref,frame)` returns the detached defined/unavailable result;
   `queue_delta_ms(ref,frame)` gives the exact millisecond remainder or null.
   `gui_delta(frame)` becomes available only after conceptual AI completion and
   uses T2 snapshot difference with the native signed-lowDWORD-to-FLOAT division.
   It does not tick a GUI or object owner itself.

`construct_creature(ref,fact)` is callable only at a certified accepted fresh
external type5 construction in receive. It requires source-owned
`externalType5Construction`, `typedAbsent`, `externalHistoryComplete` and
`registeredBeforeAi` facts; it captures **base T0**, then binds registration in
order. Ref ID retains the external bit. Proxy absence, token change, U/P/I,
replicationRemoved or retained typed A never certifies birth.
The service's private physical-clock reference explicitly stores
`nativeLifetime:null,knownLifetime:null`; actual display lifetimes need not exist
yet. Missing fields are rejected, not replaced with invented positive tokens.
The exact scope/ID, unique physical token and optional retained lifecycle epoch
fence these internal refs. `queue_delta_for_physical(id,token,scope,frame)` and
`object_delta_for_physical` resolve only that private binding. Root must first
verify the actual HUD row witness and its nativeClockOwner token/epoch; no raw
row or UI object enters the primitives. `area_transfer_references(scope,
{areaBoundary:true})` returns a detached list only for an explicit lifecycle
boundary; there is no per-frame reference enumeration.
An explicit pre-area scope can use OBJECT_INVALID as its area while area AI is
ineligible. A same-receive-batch trusted transfer remaps earlier reset receipts
only when the exact old reference transfers to the same physical owner. Pair,
frame and order stay unchanged; no provider or clock sample is replayed. Receipts
for untransferred retiring references are discarded, never retargeted by ID.
`retain_creature` preserves an exactly bound proven physical owner; lifetime/scope
changes require explicit transfers. `retire_reference` only drops an explicitly
retired scoped reference and never claims physical destruction.
`retire_current_reference(id,scope,{acceptedLifecycleRetirement:true})` performs
the same retirement through its private O(1) current-ref index. Root calls it on
accepted remove or unknown A without a duplicate ID/token mirror or a missing
token placeholder. Stale scope/missing trusted fact reject; a currently absent
entry is an explicit no-op. Old aliases/physical queries/area transfers can no
longer access the retired entry, while GUI orphan timers remain separate. A
captured reset is replayed only if its exact ref is still current, so retirement
does not scan/reset the receipt list or let an older receipt affect a replacement.

Version2 `accepted-lifecycle` facts pass only allowlisted scalar fields to the
private `acceptedLifecycle` callback: epoch/transaction/record index, operation,
type5/ID, ownership, area, string-or-null physical token, numeric0/1/null deletion
flag and explicit construction/registration/history booleans. Versionless legacy
facts cannot certify construction. This callback returns `constructed` with its
private reference/fact, `retained`, `remove`, or `unknown`. A valid unknown owner
is per-object unavailable and **does not taint T2 or unrelated certified objects**.
For fresh A, `ownerAbsentCertified` is normally false: that flag identifies the
known-absent D no-op. Fresh proof instead requires new ownership, construction,
AI registration, complete construction history and physical token, with typed
absence supplied by the private trusted callback.
Removal does not prove native physical D destruction. Root owns the eventual
private epoch/certificate reader and actual protocol/lifecycle hooks.

Process construction certainty, clock-stream coverage, and per-entity physical
certainty are distinct. Lost relevant clock events, serial/delivery gaps or a
failed stateful timer transition leave clock history sticky-unknown across new
connections. A fresh begin, first snapshot, or sampler full pass cannot repair
that clock history. Missing entity construction alone is not a clock-stream gap.
Object-only unknowns are held in a thin affected-ID set, not another world store.

`cleanup_connection()` delegates native mask2/value0 **then** mask1/value0,
preserving each native no-op/list branch. It releases scoped references only
after both succeed and keeps timers alive. Failures leave an explicit
`cleanup-partial` owner/partial state; later cleanup cannot re-certify clock
history. `destroy_process()` requires no active connection, then releases the
primitives. Neither operation invents a new absolute epoch.
Final application exit has a separate `release_process({processExiting:true})`
resource-only operation. It closes all process-owned refs and callback tables
even after partial/unsupported cleanup, without calling Pause.apply/providers,
sampling, rolling back or claiming cleanup succeeded. Its detached result keeps
`connectionCleanupAccepted:false`, prior connection/phase/failures and prior
clock certainty when a connection was still active. Missing/false fact rejects.
Normal destroy remains strict. A finally released owner cannot reconstruct a
process or reconnect; this is neither gameplay retirement nor history repair.
Cleanup may run synchronously inside receive, using retained old lower owners.
Its resets are captured as before-AI facts, not mislabeled after-AI stamps; old
references retire only after both masks succeed. Success preserves the open
frame/prefix and allows attach/begin for a newer connection in that same batch.
Post-AI cleanup uses actual after-AI stamps. Partial cleanup keeps its original
phase provenance and old scope blocked, without faking AI completion. A menu
frame without a connection can still derive the T2 GUI delta after the prefix.

The dedicated new tests are authored composition scenarios on real components,
with controlled absolute counters and lower callbacks. Retained native759 pause,
90 creature and55 FLOAT-seconds corpora are separately pinned primitive basis;
they are not relabeled as original execution of these service scenarios. Tests
cover construction/sample order, no-pause operation, T0-only rate/calendar/area,
birth/reset ordering, selected versus GUI time, incoming no-op ownership,
connection persistence, sticky coverage, unknown-owner independence, callback
failure/partial cleanup and mutation isolation. No runtime/physical-lifecycle,
actual Windows source, UI/GUI execution, server, GPU or visual claim follows.

Proposed isolated command (not executed):

`node godot-client/tools/test-native-client-clock-services.mjs native-client-clock-services-v1`

The copied headless gate has a65s direct owned-engine deadline,2MiB output and
1MiB result caps, exact source/copy/corpus/fixture/engine/six-output guards. Source
installation, DLL loading and Host/World/Session/ordinary/script owner hooks are
separate Root-owned work.
