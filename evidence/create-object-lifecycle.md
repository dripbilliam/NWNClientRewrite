# Scripted world-object creation — command and area owners

Target: NWN:EE89.8193.37-17, read-only `../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`,
SHA256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No binary patches, injected runtime observation, asset copies, or Ghidra database edits.

## Current implementation boundary

Template continuation: complete placeable/store/waypoint LoadFromTemplate
wrappers and full waypoint data-loader orchestration now have1,418 original-code
comparisons. Concrete provider wiring remains pending. See
[template loading evidence](world-object-template-loading.md), including the
verified distinction between UUID and script-variable loading. Engine243 is
still unbound; this increment does not expose additional playable spells.

October16 ownership continuation: canonical constructor repositories/AI order,
full placeable/waypoint/store destructors, placeable inventory/acquisition and
scheduled destruction are now connected. See
[world ownership evidence](world-object-ownership.md) for the original-code
comparisons, installed integration and explicit body-bag/store/GUI limits.

October16 continuation: PWK points, placeable point calculation/selection,
shared displacement, door state and area-map refresh now have owner ports and
normal-session uses. See [world-placement evidence](world-placement.md).
Historical lower-boundary descriptions below describe the original creation
oracles; these two owners are no longer unmapped implementation gaps.
CreateObject still needs concrete loader/lifecycle/presentation adapters.

`src/create_object.js` ports the command coordinator, with explicit lower
constructor, loader, destructor, placement, effect, and map-pin providers.
`src/world_object_area.js` ports its item/waypoint/store/placeable area owners.
**CreateObject is not yet bound to ModuleSession's engine243 dispatcher.**
The new pure ports are independently validated prerequisites, not a claim that
all five scripted object types already load/render in the running client.
The active spell audit remains86 unbound impact APIs/22 unavailable scripts.

`NativeAreaObjectGeometry` now exposes explicit placeable insertion/removal/
replacement against its existing native parallel-array collision store.
These operations preserve compaction, capacity and hole reuse. They do not
rebuild collision from renderer meshes or allocate replacement canonical IDs.
Unannounced membership/position/orientation/appearance changes still diagnose
and stop rather than return stale collision. Missing PWK is a diagnosed native
empty mesh; missing active rules, corrupt meshes and read failures remain errors.
The new geometry operations still need wiring through the complete world owners.

## Original command evidence

Full unwind-bounded `ExecuteCommandCreateObject140513be0..14051470f` is in
`backups/animations/native-create-object-command-v1.txt`. The Ghidra decompile
was truncated at the first free(NULL); it is not the complete control-flow source.

Required pops: INT type, STRING reference, engine structure2 location.
argc>=4 adds INT appearance; argc>=5 adds STRING tag. Defaults are0/empty.
Pop failure returns-639; failed PushObject returns-638. Successful lookup
at140513d07 uses GameObjectArray::GetGameObject140296470's BYTE status0;
it is not an object-type comparison. The command subsequently calls virtual
AsNWSArea+50; it does not reject found nonarea objects up front.
Null-area lower paths in the oracle are captured boundary observations, not
proof that native creature height or trap append can safely dereference null.

Dispatch: script1 creature,2 item,32 waypoint,64 placeable,128 store only.
Other selectors return INVALID0x7f000000. CResRef operator=14018ded0 calls
InitFromCharArray140190d30: preserve case, stop at NUL/16 bytes, pad17 bytes.
The active resolver owns case-insensitive resource lookup. The port retains
one-byte input characters to avoid Node/Chromium1252 C1 decoder differences.

| Type | Constructor | Template load | AddToArea |
| --- | --- | --- | --- |
| creature | 14037a300(INVALID,0,1) | 140397dd0 | 140380470(...,0,1) |
| item | 140462e90(INVALID) | 14046a7c0 | 140464bb0(...,1) |
| waypoint | 140508d60(INVALID) | 140509cf0 | 140508fa0(...,1) |
| placeable | 1404af9c0(INVALID) | 1404b4650 | 1404b1a40(...,1) |
| store | 1404f9a70(INVALID) | 1404fb960 | 1404fa540(...,1) |

Failed template load warns, deletes the new object, frees its28-byte location,
then pushes INVALID. Normal success/default pushes first, then frees location.
Normal PushObject failure skips that location free; failed-load PushObject
failure has already freed it. Every exit frees tag then reference. Pop-error
paths do not free an already-popped location. The replacement VM owns its JS
values; the native ownership observations are recorded, not emulated as leaks.

Creature: orientation first; ComputeSafeLocation14036aa90 uses radius20.0,
path530, flag1 and an output initially copied from the location. Any nonzero
return copies output back to the owned location. Regardless of return,
height14036a210 and placement consume the output vector, including any lower
mutation on failure. Any nonzero appearance argument creates base effect with
flag1/type81/creator callerID; integer0 remains0. This differs from summon
event24, whose appearance argument is actually placed in integer0.
No direct OnSpawn call occurs in this command; normal creature heartbeat owns it.

Other types: SetPosition14049bb40(...,0), then orientation14049b910;
placeables instead use1404b7680. Item's world subobject+48 is one canonical
object, not a second ID. Trapped placeables append ID to area158 after insertion.
Waypoints with map-note flag308 enumerate clients and send map-pin1404dc2d0
only when Client::GetGameObject1404ba840 returns an object in the waypoint area.
The native warning for invalid waypoint templates says "Invalid Store file".

## Area-owner evidence

Full original owners and constructors/load wrappers:
`native-create-object-lower-owners-v1.txt`, `native-create-object-cleanup-v1.txt`,
`native-create-object-waypoint-removal-v1.txt`.

- Item RemoveFromArea14046b1d0 and waypoint14050a470 remove spatial membership,
  clear area, and zero raw position even with no previous area. Their AddToArea
  always performs that sequence, then sets area/position and adds spatial ID.
- Store1404fa540 clears area and removes old spatial membership, but retains
  old position on a null destination. It does not share the ground-object zero.
- Placeable RemoveFromArea1404b6930 removes a nonnegative collision slot first,
  then spatial membership and first matching trap ID, then clears area/position.
  Without an old area, it leaves the stored slot untouched.
- Placeable AddToArea1404b1a40 removes first, then sets area/position, demands
  active appearance WORD32c's PWK, adds static collision only for vertexCount>0,
  adds spatial ID, calls ComputeBoundingBox1404b1bf0, then obtains static bounds
  and invokes nearby-object displacement14035c260 for a nonnegative slot.
  Those last two owners are explicit boundaries, not silently skipped work.
- Placeable ctor1404afd29 tests its requested ID. When requested INVALID,
  override5a4=1; this forces loaded Static to0. GIT's separate loader explicitly
  resets the override to0. Script-created objects must preserve this distinction.

## Validation and limits

`inspect-native-create-object.py`:427 original full-command executions, actual
CResRef copying, captured lower boundaries.422 post-pop semantic traces compare
to the port;5 additional original pop-failure cases record VM cleanup.
Coverage includes3/4/5 arguments, nonzero BOOL variants, load failure/success,
failed safe-location output, invalid selector/lookup, null area casts, BYTE data,
map-note recipients, embedded NUL, reference case/truncation, and push failures.
`native-create-object-observations.json`; final native-v3/tests-v2 logs.
Earlier probe errors are retained: helper end range and overlong stack-string
read corrected from full ASM, not weakened production assertions.

`inspect-native-world-object-area.py`:426 full original area-owner executions;
null/same/new areas, old area absent/present, flags0/1/2, collision slots-1/0/3,
null/empty/full meshes, appearance WORD narrowing and failed static-slot return.
All traces, canonical area IDs, positions and slot state compare to the pure ports.
`native-world-object-area-observations.json`; final native-v2/tests-v1 logs.
The first probe attempt had a Python loop-variable/address collision; retained.

Collision integration tests verify an existing blocker, runtime addition,
removal clearing its path, compaction and highest-hole reuse, replacement at a
new position, same backing store/capacity, active appearance selection, missing
PWK diagnostics, corrupt-PWK failure and canonical-object identity checks.
Existing NativeAreaCollisionStore independently validates original add/remove/
replace arithmetic/storage; these integration tests do not replace that oracle.

Open before engine binding: complete concrete template adapters and constructor
state, noncreature cleanup/repositories, new-object wiring for mapped action-point
and displacement owners, map-pin delivery, dynamic item/placeable rendering,
and installed authored spell lifecycle/UI checks. Creature-only render bindings
already exist but are insufficient to claim complete CreateObject support.

## Related summoning correction

The creation audit exposed two JS names for the SAME native spawn-state548:
summon event24 wrote `nativeField548`, heartbeat read `nativeSpawnState548`.
Summon delivery now writes the shared heartbeat cell before direct OnSpawn.
The original event region14038fb0f..14038fc54 and heartbeat1403a4410..1403a4bbc
are already mapped independently. Updated event-oracle comparison and a combined
event/heartbeat regression verify the state and absence of a duplicate spawn.

Installed `probe-live-summoning.mjs` now accepts an output path and counts actual
authored spawn-script calls. `live-summoning-spawn-state-v1.json` passes: actual
memorized Summon Creature VII181, creature574/master565, `nw_ch_summon_9` runs
once with state1; two heartbeat-owner calls do not repeat it. Expiry, replacement,
native dismissal, expiry-before-delivery, adoption and delayed destruction pass.
All diagnostics remain recorded, including existing impact-broadcast and missing
script warnings. General AI/startup isolated; no rendered/campaign/network claim.

Full1,659 tests and production build pass after all changes:
`create-object-owners-full-tests-v2.txt`, `create-object-owners-build-v2.txt`.
Build retains its existing large-bundle warning. No running probes remain.
