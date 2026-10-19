# Missing-target client creatures and expiry — 2026-10-17

Projectiles whose referenced target is missing can now use the original temporary
client-creature path: load `c_dummy`, register an internal client ID, position its
attachment nodes, force appearance201 and expire it after travel duration+500.
Authoritative objects and their ID allocation remain untouched. This is progress
toward the full spellcasting/combat/campaign goal, which remains active.

Read-only NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original installation and Ghidra project unchanged. Previous verified checkpoint:
`backups/projectile-impact-1869-20261016-v1.zip`,9753 files/122516303 bytes.
Verified checkpoint: `backups/client-dummy-1877-20261017-v1.zip`,9792 files,
123799187 bytes; all archived entry lengths and SHA256 hashes verified.

## Native creation and model provenance

Safe-projectile receiver1407ac670, fragment1407aca8e..7acc54, requires requested
target ID!=INVALID and missing resolved target. Allocation7acaa8 requests480 bytes,
then creature ctor1407fb140. Virtual f0 at7acb18 loads resource `c_dummy` with
part255/mode0. Verified creature vtable140e474e8 f0 points to140802cc0, whose
warning identifies CNWCCreature::LoadModel. This loads an MDL, not a UTC blueprint.
An initial read-only UTC lookup failed; inspecting the actual owner corrected
that interpretation before runtime implementation. Installed `c_dummy.mdl` has
only dummy nodes: physical root, rootdummy, hand/headconjure, Impact and hands.

On load success and two successful player lookups plus nonnull player area30,
AddInternalObject140295d40 runs at7acb72. Nonzero status aborts receiver. SetId
virtual8, area virtual118, AI registration1407675d0, scene virtual138 with area248,
position virtual128 and desired-position2c0/2c8 follow in that order. Stats300+cc
receives WORD201 at7acc0b. This does not reload its model from appearance.2da:
the installed row201 RACE is c_cmbtdummy, but native keeps `c_dummy` loaded.

At7acc38 it calls140765920(dummy,1,1,travel+500), with DWORD wrap. It then sets
INT104=1 and obtains the NWC object pointer via virtual18. If model/player/area
admission failed, the original still schedules this allocation but leaves the
requested target ID unchanged and does not register area/array/AI ownership.
Allocation or insertion failure instead aborts. The local adapter explicitly
reclaims inaccessible unregistered allocations while preserving that requested
ID/projectile behavior; it does not reproduce an orphaned native allocation.

## Delay, fade and removal

Setter140765920 rejects temporary104 exactly1 or blocked108!=0. Otherwise it
stores target BYTEa9, delay INTac and duration DWORDa4; nonzero delay snapshots
world time9c/a0. It branches on native client config1c and controlled player ID,
invokes display virtuals210/200/218/1f8 and writes visiblef4 as observed.
The port retains these virtual offsets instead of inventing semantic names.

Expiry/fade140762e40 compares BYTEa8 to a9. When equal and delay!=0, it subtracts
world times and compares only unsigned millisecond remainder to duration; whole
elapsed days do not participate. When unequal it uses snapshot microseconds/1000,
DWORD conversion, target-alpha provider1407630e0 and native FLOAT fade/clamp
ordering. Fade-out completion can reset the timer and call model scene virtual8.
The ordinary dummy begins with a8=a9=1, so it directly uses the expiry branch.

Creature AI1407fbd10 calls this at7fc56f. Nonzero result removes AI with140767b40,
deletes the client ID with1402963d0, then invokes destructor only for status0 plus
nonnull removed pointer. These branches are independently ported and tested.
Full AI scheduling, constructor/model loader and display virtual internals remain
separate boundaries. The old informal label for765920 alone was insufficient to
prove lifetime; the receiver, expiry and deletion consumer now establish it.

## Implementation and delivery

`client_object_fade.js` ports setter/expiry/fade state. `client_projectile_dummy.js`
ports receiver creation and removal ordering. `ClientProjectileDummyPresentation`
owns async models, the client area/AI lists and cleanup. It records display
virtual requests and diagnoses its local mode2/scene/cache adapter. Native
target-alpha, fade-completion scene and snapshot-time services remain explicitly
unavailable if a different fade state is requested; no guessed alpha fallback.

`ClientProjectilePresentation` passes the local player ID, uses internal dummy
IDs for targeting/impact, ticks expiry and disposes pending/registered models on
teardown. An asset that finishes after disposal cannot resurrect either object.
The broad dummy-unimplemented message is replaced by specific model/registration/
player/update failures and scene adapter diagnostics. The inbox now forwards
absent objects to the native fallback. A different live canonical object reusing
the same ID is still rejected, including replacement during async loading.
Deletion by itself no longer cancels an otherwise valid queued projectile.

## Evidence and validation

`inspect-native-client-dummy.py` final capture executes unchanged receiver,
setter, expiry and AI removal fragments. Ctor/model loader, array/area/AI/scene
virtuals, scalar timers, target-alpha and alpha output are captured lower services.
Initial fixture issues (instruction boundary and target-alpha lower scope) were
corrected before final capture. Synthetic null-handle delayed fade-out completion
states that the original dereferences are explicitly excluded; not claimed valid.
Controlled-player and other-object branches are both covered in capturev4.

`native-client-dummy-observations.json` has9996 cases covering allocation/model/
player/area/insertion admission, INVALID IDs, wrapped durations, delay guards,
native modes/controlled IDs, fade state, alpha, timer boundaries/day remainder,
and deletion status/pointer conditions. Three native tests compare exact calls,
state and FLOAT bits. Four renderer integration tests cover actual temporary-ID
targeting/impact/expiry, new canonical IDs during loading, teardown races and
failed model fallback. The inbox regression checks absence versus replacement.
All1877 tests and build pass.

`installed-client-dummy-v1.json` is the final read-only installed-resource probe.
It uses untouched wizard active spell metadata (selected spell37/vpr_los/path1),
real MDL hierarchies, ModelAnimator and visual pose/parent services in a headless
Three scene. Source/target are deliberately absent header IDs. Dummy id0 and
projectile id1 remain separate from the player/server registry. Impact attaches;
projectile is gone at501ms; dummy survives999ms and is removed at1000ms. Both
models/scene nodes are reclaimed, and the authoritative ID cursor is unchanged.
Snapshots are cloned at capture time. It is not a browser missing-target test or
actual network object deletion. An initial broad assertion found the known
moving loop-audio gap; the final probe retains it and validates its resource
against active ProjSound. No unrelated unimplemented/failure is allowed.

Normal installed casting UI regression passes on the final build: chant, CC8
start/release, conjure/fade/cleanup and body impact attachment/cleanup. Renderer
errors are empty. That browser run uses a live target; the missing-target path
is covered by the native, renderer and installed headless probes above.

## Remaining scope

Whole native creature/model/display/cache/perception/scene replication and AI
scheduling are not complete. Generic target-alpha context remains a lower
boundary. Missing-source short-direction edge cases, shield equipment/models,
ranged visuals, linked/ref and scene-hit paths, child spawns, moving loop audio,
remaining effects/engine calls, combat and campaign parity remain open.
