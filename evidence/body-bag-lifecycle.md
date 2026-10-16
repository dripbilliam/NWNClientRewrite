# Body-bag spawning, ownership and rendering

Target: NWN:EE89.8193.37-17, read-only original
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No original assets, executable or Ghidra project were modified or copied.

## Mapped owners and concrete integration

`body_bag.js` ports full SpawnBodyBag14049c170..c4ae and
LoadBodyBag1404b4080..4648, plus bounded area event17 at14035dba0..dc26.
The synthetic loader does not request a UTP. It initializes native scalar fields,
localized strings, empty resrefs/scripts, portrait, animation and module tag.
Native AsTAG14016ac40 filters the literal `Body Bag` to `BodyBag`; a raw string
assignment would create the wrong lookup tag. Unnamed scalar offsets stay numeric.
Source name is copied into the description; display name becomes localized strRef
0x9cac. Spawn writes final HP12/plot1/DieWhenEmpty1/body-bag flag5141.

The spawn coordinator retains both virtual type queries, area lookup, creature
droppable-count/placeable direct-count short circuits, lootable-corpse fallback
destruction, link-before-load ordering (including the stale link on failure),
transfer before payload allocation, ignored transfer count, and repeated area
lookup. Allocation/load/payload failure paths are independently observed. The
bag's canonical ID and source position are delivered through area event17 after
exactly1000ms, not immediate insertion. Area event lookup requires exact status0,
then AsPlaceable; stale/wrong-type references still release the payload.

`ObjectLifecycleRuntime` connects synthetic load, active physical bodybag/
placeables table queries, canonical registration, direct item transfer, tag,
repo/PWK/area/spatial insertion and event17. `world_destroy_event` now reaches
that body-bag owner for populated placeables rather than stopping at an
unsupported diagnostic. Constructor qword510 at1404afd42 initializes source ID
INVALID and flag5140. These are separate cells from collision slot50c.

`acquireCorpseItems` was already independently ported. Its placeable path now
uses normal native acquisition/removal/repository/possession adapters, preserving
the actual item IDs and size-bucket ordering. The native placeable area-add port
is connected; `insertPlaceable` accepts the already fetched PWK to avoid duplicate
resource queries. Empty PWKs still get area snapshot/spatial membership without
allocating collision slots. The existing displacement/ComputeBoundingBox owners
remain responsible for populated PWKs.

`main.js` now loads and binds newly inserted placeables from active
placeables.2da, MDL/animations and bitmap fallbacks, with diagnostics for every
failed final model/bitmap load. Async completion rechecks canonical record,
area, appearance and scene identity. Destroyed/transferred placeables detach
their render views/animators without deleting simulation IDs. Initial area
render skips destroyed authored records when revisiting; runtime bags bind again
from canonical membership. Object diagnostics expose placeable projection/position
for inspection and UI regression input.

## Independent original-code comparison

`inspect-native-body-bag-owners.py` executes original machine code, including
the fixed-literal AsTAG owner. It captures lower construction, counts, appearance,
transfer, scheduler, insertion and string primitives. ASCII classification is
captured for the literal, not evidence of arbitrary locale-dependent AsTAG parity.
Six full loader cases,240 full spawn cases and70 bounded area-event cases match
three comparison tests. They cover wrong event/type/status, nonzero load returns,
absence of area/items, lootable0/1/2, allocation failure, payload failure and
different appearance/transfer results. Final capture
`body-bag-owners-native-v2.txt`/`native-body-bag-owners-observations.json`.
The first comparison failure was an incorrect expected fixture count336 instead
of240; all original trace comparisons already matched and the count was fixed.

Research: `native-world-destroy-close-owners-v1.txt`,
`native-body-bag-loader-count-v1.txt`, `native-body-bag-tag-owner-v1.txt`,
`native-area-loot-event-owner-v1.txt`. Event global140dfc184=17 is verified in
`native-placeable-close-gui-owners-v1.txt` and `native-world-animation-vtable-v1.txt`.

## Installed and rendered checks

`probe-installed-body-bags.mjs` passes seven populated Prelude placeables in
m0q1a/m0q1d. Bag IDs574..580 replace sources52/54/56/64/385/416/426. Every actual
item record/ID survives transfer, source repo/PWK/spatial ownership is removed,
and the new bags remain unplaced at999ms and enter the right area at1000ms.
Tag lookup, localized state, appearance13 from active data, script inventory
enumeration, final HP/plot and canonical player565 are checked. All load
diagnostics retained; no new errors. AI/startup disabled. Final
`body-bags-installed-v1.txt`/`installed-body-bags-v1.json`.
The preceding ownership regression also passes after these changes:
`body-bag-ownership-regression-installed-v1.txt` and corresponding JSON.

`smoke-live-body-bags-ui.cjs` builds an in-memory archive fixture: a real installed
UTI is placed on a nearby placeable with a tiny authored OnUsed NCS calling
DestroyObject(OBJECT_SELF,0). The production bundled client receives actual
right-click/radial Use input. Source model3 disappears and runtime body-bag575
appears with modelplc_b04, distinct ID, same position and real right-click
pickability. Switching to m0q1d and back keeps bag575 and does not resurrect the
source render. No direct session hook or proprietary fixture archive is saved.
Final `body-bag-ui-v5.txt`, `live-body-bag-ui.json` and PNG.
The existing preview sun is enabled for the inspected screenshot; this is not
evidence of native area-lighting parity. Earlyv1 used a wrong hover assertion
(the radial had actually selected the source) and a nonexistent log.flush helper;
its owned process was terminated, both fixture errors corrected, later runs exit
normally. Dark/failure screenshot retained separately.

All1674 tests pass (`body-bag-full-tests-v2.txt`), production build passes with
the existing chunk warning (`body-bag-build-v1.txt`). Rendered polymorph and
summoning/associate dismissal regressions pass (`body-bag-polymorph-ui-v1.txt`,
`body-bag-summoning-ui-v1.txt`). All processes reached terminal status.

## Remaining gates

Subsequent [inventory GUI ownership](inventory-gui-ownership.md) work maps the
lower GUI reset, placeable open/close and observer callbacks described as missing
below. The native UseObject action and rendered loot/pickup UI are still pending.

This establishes populated-placeable loot preservation and world presentation.
The loot inventory GUI/action and actual player pickup are unfinished: the current
legacy placeable Use route still requires an OnUsed script rather than opening
an inventory owner when appropriate. Full CloseInventory LUO cleanup is also
unavailable for live observers. Creature corpse transfer still needs native
equipped-item CopyItem, virtual localized-name semantics, death scheduling and
other death owners; those paths remain diagnosed rather than falsely bound.
General CreateObject243 remains unbound pending UTP/UTW/UTM loader/tag/map-pin
adapters; store inventory/pricing/GUI remains unfinished. No save/protocol,
complete spell ecosystem, combat or continuous campaign acceptance claim.
