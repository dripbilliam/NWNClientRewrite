# World interaction points and creature displacement — October16,2026

Target NWN:EE89.8193.37-17, read-only installed `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No original install writes, patches, injection, asset copies or Ghidra edits.
Read-only Ghidra name queries confirm BudgeCreatures14035c260,
SetOpenState140423230, and door constructor14041d6b0.

## Connected behavior

`object_surface_mesh.js` imports the PWK's two use points from active resources.
`placeable_action_point.js` implements their world calculation and selection.
Canonical placeable construction initializes vectors550/55c; initial native
collision loading computes them using active PWK/terrain. Native use-range
checks and the placeable UI approach point now consume this canonical state,
instead of the renderer's separate approximate array. Scene input binding waits
for that geometry. This does not finish placeable use/inventory actions.

`world_displacement.js` implements shared area displacement, door state, and
same-area player-map refresh. ObjectLifecycleRuntime supplies active collision,
safe-location, canonical lookup, action points and sorted SetPosition.
ModuleSession.receiveDoorUseEvent awaits both linked-door coordinators before
invoking only the source callback. Obsolete door.budge and door.automap-update
unimplemented reports are removed. Dynamic creation adapters remain to be wired.

## Original owners and observable rules

| Owner | Original range / call sites |
| --- | --- |
| PWK constructor | 1402cdda0..1402cde3d |
| PWK loader | 1402ce0b0..1402ceaeb; dummy block1402ce311..1402ce55e |
| placeable constructor points | 1404afae3..1404afb00 |
| ComputeBoundingBox | 1404b1bf0..1404b1e0b |
| nearest placeable point | 1404b3f20..1404b4057 |
| BudgeCreatures | 14035c260..14035c58c |
| door SetOpenState | 140423230..140423396; budge call140423381 |
| area UpdatePlayerAutomaps | 140372900..1403729ac |
| door bounds import | AddToArea14041e410..14041e6f3; bbox call14041e517 |
| door bounds constructor | 14041d777..14041d785 zero six floats4c8..4dc |

PWK dummy grammar skips exactly four name bytes, then recognizes pwk_use01/02
or pwk_dp_use_01/02. Extra suffix bytes are allowed. Unknown dummy nodes and
dummy endnode lines retain the previous slot: a later unrelated position can
overwrite that point. A trimesh node clears the slot. Invalid numbered use nodes
warn and retain the prior slot. Warnings reach diagnostics with resource/node
context; unsupported malformed data fails explicitly. Dummy orientation does
not transform these raw points.

Despite its name, ComputeBoundingBox calculates interaction vectors, not AABBs.
A zero local vector leaves its old world cell unchanged. XY uses raw orientation.
Local Z only gates the zero test: old world Z plus object Z is passed to height,
which replaces it. One-sided rejection is atanf((objectZ-groundZ)/horizontalDistance)
>1.0472 (double140df3778), without absolute value. Original vector+=14022b180,
magnitude1402303d0 and atanf140c94418..140c945f9 execute in the oracle.
NaN/CRT exception-state input remains explicitly diagnosed.

Nearest point first tests point0 for all zero; if zero it returns object position
even when point1 exists. Zero point1 selects point0. Otherwise float32 squared
distances select point1 on ties. No walkability test/recompute occurs here.

Budge uses margin5.0 (140d810b0), search radius10.0 (140d8216c). Initial X seek is
originX-minX-5; later strict XY tests use world bounds +/-5. It skips noncreatures
and safe creatures; X>=maxX+5 ends traversal. SetPosition reorders the live list,
without a snapshot/dedup pass. Flag0 adds a normalized3D unit direction away from
origin to the old position; zero delta uses native [1,0,0]. Nonzero flag uses
door/else placeable nearest action point. Missing targets retain the preceding
candidate, initially zero. SafeLocation receives an input copy and persistent
output. Only nonzero success calls SetPosition(...,0); failed lower mutations
can still affect later candidates. No jump/subarea callbacks are invented.

Door state narrows to BYTE, forced3 when VisibleModel498==0. States0/1/2/3 map to
animations22/50/51/72. States1/2/3 refresh player maps even when unchanged.
Changed non3 states budge: closing passes1, opening passes0. Unknown BYTE states
still budge, with no animation branch. Door bounds4c8/4d4 use the all-state DWK
bounding calculation; empty geometry retains constructor zeros. Area-map refresh
only enumerates clients with flags&3 nonzero, updating each same-area canonical
creature's own ID.

## Verification and limits

1,070 original-code cases:

- inspect-native-placeable-point-loader.py:55 full constructor/loader cases;
  offsets, both names/slots, suffixes, repeated/unknown/invalid nodes and CRLF.
- inspect-native-placeable-action-points.py:514 compute/nearest cases;
  scaling, zero/retained cells, f32 magnitude/height inputs, signed slope,
  large coordinates, null area/mesh, WORD appearance and ties/fallbacks.
- inspect-native-world-displacement.py:501 shared displacement, full door state
  and area map cases. Normalization runs unchanged. Sqrt/CRT flag raise,
  resources/canonical lookup, seek/placement/action points, animation/map update
  and SetPosition are captured boundaries. Synthetic live-list reorders compare
  through NativeAreaSpatialArray. Existing independent native collision,
  safe-location, SetPosition and spatial-array checks remain relevant.

JSON data: native-placeable-point-loader-observations,
native-placeable-action-point-observations, native-world-displacement-observations.
Final native logs: loader-v1, action-points-v4, world-displacement-v1.
Earlier errors retained: no-unwind getter recaptured by verified leaf CFG;
magnitude's distant sqrt tail verified in existing full capture; atanf RET
required half-open end945f9; CRT flag dependency captured; Python address/loop
variable collision fixed. No production assertion was weakened. The paired-door
unit fixture explicitly isolates these separately validated lower owners.

probe-installed-world-placement.mjs / installed-world-placement-v1.json PASS:
176 Prelude placeables,168 with nonzero authored points; actual GetUseRange
equals UI point conversion. Closing a real door on player565 moves its center
[28.1,-.01,-15] to [27.2,0,-14.6251688], safe-point1. Real PWK blocker3 moves
that same player one unit out of its blocked center, safe-point1. Registry
record/stats reference/spatial ID persist, with own-map refresh565/565.
All load failures/warnings retained. Actor positioning is test setup; general
AI/startup/OnOpen scripts are isolated, not a campaign playthrough.

Installed summoning regression passes after geometry changes:
live-placeable-points-summon-v1.json. Rendered --polymorph passes self radial,
prepared parent-slot consumption, authored impact, mesh/animation rebind,
canonical ID and radial restoration. live-polymorph-ui.json and transformed/
restored PNGs, world-placement-polymorph-ui-v1.txt. Images inspected: existing
wall occlusion, darkness and overbright FX remain. No camera/lighting/FX parity
or rendered door-input acceptance claim.

All1,665 tests/build pass: world-placement-full-tests-v2.txt,
world-placement-build-v1.txt (existing large-bundle warning). All processes
terminal. Full goal ACTIVE. CreateObject243 still unbound: templates/constructor/
cleanup/repositories, map-pin delivery, dynamic noncreature presentation, new-area
adapter wiring and installed authored spawn spell/UI lifecycles remain open.
