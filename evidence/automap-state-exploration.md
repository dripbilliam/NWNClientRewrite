# Character automap state and exploration

Target NWN:EE89.8193.37-17, unchanged read-only original
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Ghidra and full assembly plus isolated Unicorn executions; no binary/assets or
Ghidra edits. The full spell/combat/campaign goal remains active.

## Observed storage and owners

Creature6c8 is an ordered native area-ID list, distinct from6d8's array of
128-byte buffers. INT6e0 controls automatic exploration. Tile/area cache6e4/5/8
is separate. ClearAutoMapData140387b40..140387bec releases buffers and ID storage
without resetting that flag/cache. ReconcileAutoMapData14039dbc0..14039ddad
does nothing for a null outer pointer. Otherwise it compares module area order,
moves buffers by first old matching ID, nulls transferred slots, releases old
ownership and creates zeroed buffers for new IDs. It does not allocate another
canonical game object or replace an area ID.

SetAutoMapData1403a2d50..1403a2f31 preserves buffer allocations when counts
match, rebuilds when counts differ, then reconciles. LoadAutoMapData140397400..
1403975d3 first clears maps and reads Mod_MapNumAreas, Mod_MapDataList and
Mod_MapAreasData. An existing empty list exits before reading IDs/autoexplore.
ReadFieldVOID1401a1870 copies only the available bytes; short or absent blobs
leave indeterminate tails. The replacement explicitly rejects those malformed
states instead of inventing zeroed saved data. This loader is implemented as
an import owner; normal BIC selection does not pretend to be the native IFO
saved-player/TURD load path. Save transport is still unfinished.

PostProcess block14039b897..14039b9e6 initializes maps only for object-PC89c
nonzero or a possessed familiar, and only when6d8 is null. It uses current
module area order and zeroed buffers. Constructor argument3 supplies flag6e0;
LoadLocalCharacter call1404bc106 and area LoadCreatures call1403606b2 both pass1.
The bounded block comparison is not a complete character PostProcess claim.

GetTileExplored140393270..140393337 and SetTileExplored1403a4330..1403a4404
resolve the canonical area, reconcile a missing index, then use signed
width*y+x and truncating division by8. They do not introduce their own XY
bounds. Invalid allocated memory accesses diagnose unsupported data. SetAll
1403a2ac0..1403a2baa fills area BYTE348 bytes; clearing a client-owned map
immediately calls UpdateAutoMap. Area LoadArea block14035f72b..14035f750
computes BYTE348 by f32 product/8 and original CRT ceilf140c7fef0.

UpdateAutoMap1403a7390..1403a76ab checks raw6e0 and a canonical target creature,
truncates actor native XY/10 to tile coordinates, then branches on area flags&3.
Flags&3==0 reveals a3x3 square in X-outer/Y-inner order. Other values invoke
ExploreArea14036bb40..14036bc8a with range8. ExploreArea has no reconciliation:
missing target map returns0; otherwise it merges nonzero DFS depths and returns1.
Assembly14036bc69 proves that return despite misleading decompiler cleanup.

InterTileDFSExploreArea14036ce60..14036d557 stores a tile's remaining depth
before its final-ring and coordinate checks. It selects door visibility,
visibility or path graphs and follows original entrance order. It checks
closed doors in the half-unit boundary band when both SET tiles declare doors.
Selection/blocking tests Appearance+3f8, not VisibleModel+498. Appearance0
reads rules+138 GenericDoors at GenericType+3fc for BlockSight. Load2DArrays
1402b4209..1402b42ff identifies that table. The actual GetINT fallback output
is retained even on failed lookup. Rotation and f32/double threshold behavior
are preserved. Indeterminate resources or unsupported dynamic door geometry
remain errors, never permission to explore through missing data.

## Live integration and script entry points

`automap.js`, `automap_exploration.js` and `automap_runtime.js` connect PC
PostProcess, creature heartbeat tile changes, AddToArea/associate map callbacks,
DM reveal and destruction cleanup. The existing local PC area adapter applies
the verified entry-time update too. This does not replace that adapter with the
native ClientArea send/ready protocol. Tile helpers now accept the selected
graph kind/orientation as well as the usual path graph defaults.

`automap_script.js` implements decoded bodies for ExploreAreaForPlayer403,
Set/GetTileExplored866/867 and Set/GetCreatureExploresMinimap868/869. Owners
14051d830,140548aa0,140510f30 resolve objects in native order. The tile APIs
accept only unsigned XY<32 and setters return the previous state. Autoexplore
setters preserve raw INT values rather than normalizing to Boolean. These
comparisons use valid typed arguments; VM stack underflow/type errors are a
separate existing owner, not established by these fixtures.

## Validation and remaining limits

5,465 original-code observations:2,200 storage/import/bit/coordinator cases,
1,536 full recursive DFS cases including actual coordinate rotations,
1,089 original loader/CRT sizing cases and640 script-wrapper cases.
`inspect-native-automap*.py`, the four observation JSON files and native tests
retain the exact lower-helper boundaries. DFS uses captured graph/region
providers; these finite synthetic cases are not a native running-map oracle.

`probe-live-automap.mjs` loads actual Prelude character/SET/WOK/DWK/2DAs.
PC maps begin zeroed in all five module areas; NPC maps stay null. Entry,
heartbeat and local library/training/library transfers preserve data. Library
reveals9/9 tiles; the training spawn reveals7/144. Reordering the real local
module area list preserves each buffer by ID. Reveal/clear and all five script
APIs pass, including raw flag2 and flag0 stopping exploration. The initial
heartbeat may only initialize its perception timestamp; the probe observes the
subsequent tick independently. Reports:live-automap-v5.txt and live-automap.json.
Known absent plc_w02.pwk and script2.ncs remain diagnosed.

Rendered regression:automap-transfer-ui-v2.txt and the latest
live-associate-transfer-ui.json/png pass installed spell radial casting,
Follow/Stand, both area changes, unchanged canonical summon575/master565 and
radial Unsummon/removal. Zero browser errors; engine DoSinglePlayerAutoSave
still fails once and remains recorded. The first attempt missed model picking
after camera reset/room-wall occlusion; the fixture now applies the same ordinary
orbit input after each render. Both failed and successful reports are retained.
The successful dark library screenshot was inspected. It is not clean campaign
acceptance, native map-fog presentation, persistence or wire-protocol parity.

1,392 tests/build pass; final reports automap-all-tests-v3.txt and
automap-build-v3.txt. Verified backup:backups/automap-1392-20261015.zip,
report backups/animations/automap-checkpoint.txt. Continue with native PC area
loading/first-client activation, map fog/persistence and actual autosave. Broader
spell/combat/campaign completion remains open. The preexisting sound traversal
also needs its Appearance/VisibleModel use audited against its own owner.
