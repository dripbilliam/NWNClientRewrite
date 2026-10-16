# Native door landing and terrain material queries

Target NWN:EE89.8193.37-17, read-only original
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Ghidra/full assembly plus isolated original-instruction execution. No game
binary, installed assets or Ghidra annotations changed.

## Owners and behavior

`src/door_action_point.js` implements GetActionPoint1404201e0..1404202da and
GetNearestActionPoint140420360..1404207e3. Native+4c0 points are local XYZ
vectors, transformed by the door's existing native position/orientation with
f32 multiplication/addition order. INT animations22/50/51 select closed/open1/
open2 pairs, and side narrows BYTE. Unknown animations transform zero, returning
the door's position. The native call sites pass side0 and1; invalid reads beyond
the six vectors are explicitly unavailable rather than clamped.

Nearest-point selection samples animation before GetArea, then optionally
forces22 for a jump. Ties choose the second point. A nearer first point failing
PositionWalkable tries the second; there is no reverse fallback from a failed
second to the first. For nonclosed animation the closed pair may replace the
candidate only at strictly smaller f32 3D distances, starting with native bound
1000 if no candidate succeeded. A zero result falls back to the door position.
This does not use the preview door-point rotation/nearest-vector approximation.

`object_surface_mesh.js` now retains six native DWK action-point vectors. The
surface ctor1402cecf0..1402cedb8 calls Vector140047300..14004730c six times to
zero them. Loader1402cf720..1402d0100 uses fixed two-character model prefix,
case-sensitive `_DWK_dp_closed/open1/open2_01/02` names and exact dummy-node
prefix spacing. Position is copied directly, without dummy orientation or
collision-node transform. Repeated points overwrite the same slot. Malformed
recognized state/index and incomplete numeric data still diagnose unsupported
input; the loader comparison does not prove all malformed/binary DWK grammar.

`tile_surface_mesh.js` adds the native material query1402bedf0..1402bf05e:
first containing physical walkable face, using f32 horizontal edge signs;
ignore Z and denied faces, and return material0 on a miss. Tile wrapper
1404fdc90..1404fdd1f rotates real XY to canonical via1402c5760..1402c57ca.
Area14035eaf0..14035edb7 selects native32-slot ten-unit tile coordinates,
checks dimensions, and subtracts tile origin. PositionWalkable140364bc0..c8a
queries active `surfacemat.2da` column `Walk` for that material, consumes the
GetINTEntry output even when its success flag is0, and returns value!=0.
No hardcoded material whitelist or browser triangle picking is involved.

NativeAreaObjectGeometry loads the active appearance DWK, populates native
VisibleModel+498 and checks its existing mutation signature before point use.
Both live GetUseRange and jump-to-door now call this shared owner. Jump uses
native XYZ; use-range returns renderer XYZ and asks native terrain height.
Loaded doors now initialize native animationD8 from authored AnimationState,
matching LoadDoor140420985/990 → SetOpenState140423230. Existing setter maps
states0/1/2/3 to animations22/50/51/72. Live door state changes retain that owner.
The preview click adapter and paired-door mirror also synchronize animationD8
when reporting state changes. A regression covers open1/open2/close; otherwise
native landing queries could retain a closed animation after a normal click.
This adapter synchronization does not claim native creature door-action parity.

## Validation

- `inspect-native-door-action-points.py`: **2,512** unchanged original point/
  selection executions, including all resting animations, unknown states,
  BYTE narrowing, nonunit orientations, ties, zero and far points, forced
  closed selection, missing area and varied walkability returns. Vector
  transforms, magnitude and selection execute; GetArea, PositionWalkable and
  scalar sqrt runtime are captured lower boundaries.
- `inspect-native-door-point-loader.py`: **43** original constructor/loader
  executions with synthetic ASCII. Native line scan, fixed naming offsets,
  case/spacing gates, state/side and storage execute. Resource/heap/libc numeric
  parsing/comparison are captured boundaries. No proprietary DWK is copied.
- `inspect-native-surface-material.py`: **1,080** full surface/tile/area/walk
  query executions, original rotation included. Synthetic loaded triangles
  cover physical order, overlap, reversed winding, boundaries, outside area,
  all quarter-turns, Z independence and 2DA fallback/nonzero values. Native tile
  location, GetINTEntry and temporary string heap calls are captured; this
  supplements existing separately checked geometry/table owners.
- `probe-live-door-placement.mjs`, `live-door-placement-v2.txt,json`: reads
  all**38** doors in installed Prelude library/training-room areas. Actual
  DWK points for all states, native terrain Walk queries, GetUseRange and
  queued jumps to**three** doors succeed. The door receives its own front open
  action, preserving the original target-ID slot, before safe landing. Startup
  and general AI are isolated. Only the known absent installed `plc_w02.pwk`
  is logged; the report has one expected error, **not errors0**.
- Prior queued point/object/forced jump regression still passes
  (`door-jump-base-regression-v1.txt`). Production right-click summon plus
  Follow/Stand/Unsummon/rendered removal passes in isolated Electron
  (`door-placement-summon-ui-v1.txt`, refreshed `live-summoning-ui.json/png`).
- Original dialogue/scripted door/transition regression still passes
  (`door-placement-area-regression-v1.txt`); known absent script2 remains logged.
- **1,386 tests and production build pass**:
  `door-placement-all-tests-v2.txt`, `door-placement-build-v2.txt`.
  Original executable hash reverified unchanged.

## Remaining scope

This closes the live door-point dependency of native jump5/48 and use-range.
It is not complete spellcasting, combat, door interaction or campaign parity.
Creature-owned door approach, native Budge/automap side effects, player
ClientArea/automap handshake, module limbo and replacing the legacy scripted
jump adapter remain unfinished. Original ClientArea sender1404cd9d0 is the
next transfer research entry. Inter-module/server acceptance remains separate.

Verified checkpoint: `backups/door-placement-1386-20261015.zip`; report
`backups/animations/door-placement-checkpoint-v2.txt`. Prior1385 checkpoint is
retained before the preview-state synchronization fix. Goal remains active.
