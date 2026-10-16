# Concrete waypoint templates and tag/string ownership

Target: NWN:EE89.8193.37-17, read-only
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No original resources/processes or Ghidra database entries were changed.
All special GFF fixtures stay in memory; captures contain derived evidence and
metadata, not copied game assets.

## Concrete adapter

`src/world_template_runtime.js` connects the previously compared waypoint
LoadFromTemplate509cf0 and LoadWaypoint509f80 owners to ModuleSession's active
resolver and parsed GFF metadata. Complete owner evidence/comparisons remain in
[template loading](world-object-template-loading.md). The runtime adapter loads
UTW2058, clones owned authored data, applies typed fields and native string/
localized assignments, normalizes orientation, inserts the module tag, imports
UUID, applies the wrapper's requested template afterward, and loads variables.
UUID load failure is warned/retained and ignored by the waypoint owner; locals
and the outer requested-template assignment still occur. No canonical ID is
allocated by loading, localization, UUID, tag insertion or variable import.

BYTE map-note reads normalize to BOOL; wrong types retain an existing note.
Localized Name320 and MapNote310 are preserved as native localized values.
The name's first embedded entry also supplies compatibility UI label metadata;
this is not a newly reconstructed TLK/language presentation owner.
Native constructor508d9b..508daf constructs both localized members; the runtime
now initializes Name320 as well as Note310. Destructor508e61..508e75 releases
Name320 before Note310, then the existing base-object cleanup runs.

`ObjectLifecycleRuntime.addWaypointArea` connects native ground-object insertion
508fa0 to canonical area/spatial owners. It removes old membership, zeros old
position, sets the destination/position and inserts the same ID. A null area
retains no membership and leaves position zero. Waypoints do not join AI lists.
Template/data loading itself does not insert an area or send a map-pin message.

Resource-not-found is diagnosed, yields loaded0, releases the wrapper resource
and emits the original template warning. The caller owns object destruction
after a failed template load. Other parse/I/O failures are retained and thrown;
the adapter does not claim exact native corrupt-resource recovery or OOM.
`world-template-resource-ctor-v1.txt` and its Ghidra companion map CResGFF ctor
19e660 (including loaded-state initialization, resource registration/demand),
but do not port the whole resource system. CreateObject's own reference truncation
is already separately mapped; installed references here fit that native limit.

## Tag insertion and query corrections

`src/module_tag_lookup.js` projects native module lookup entries into grouped
IDs. AddToLookupTable47a930..47ab3b calls Left(64), then copies its C-string
prefix. SortIndex47d450..47d4ed is a lower-bound search, so duplicates insert
before existing duplicates. Case remains significant; full object tags are
separate from truncated lookup keys. Common register/item/creature/body-bag
insertion and cleanup now share that key handling. Existing generic register
paths still skip fully empty tags; the concrete waypoint loader follows its
unconditional native AddToLookupTable call. Full GIT-loader unification remains
separate work.

The two script queries have different owners:

- GetObjectByTag47d1e0..47d2cf rejects an incoming stored length0, then returns
  the matching table ID directly. It does not re-resolve that ID or compress
  ordinals by filtering missing objects. The binding now preserves stored IDs.
- GetWaypoint47de70..47dff0 admits an empty tag, walks matching table entries,
  resolves each through GameObjectArray, and selects native type BYTE12. It
  skips stale IDs and other object types. The binding uses this distinction.

Existing UI `byTag` convenience queries still return live records. That is
separate from the native script query's raw-ID semantics. A template reload
adds its new tag without removing prior tag entries; destruction removes one
matching current-tag entry. The old key may therefore retain an ID after its
object is removed. Original RemoveFromLookupTable484bd0..484d65 confirms the
current-key/id check; it does not remove all aliases globally.
Lookup underflow/OOM and arbitrary reads outside original allocations are not
emulated. Negative ordinals remain outside the validated cases.

Full ASM: `world-template-tag-add-v1.txt`, `world-template-tag-index-v1.txt`,
`world-template-tag-query-v1.txt` (VM wrappers, inspected),
`world-template-tag-query-lower-v1.txt`, `world-template-tag-remove-v1.txt`.

`inspect-native-module-tag-add.py` executes complete original Add/sort-index,
GetObjectByTag, GetWaypoint, Left16bcb0 and assignment03d8c0 bodies.92 sequences
cover1,983 insertions and11,898 queries, checking every intermediate state.
Cases include empty/mixed-case/1252/NUL/over64 tags, duplicate order, mixed
native object types and stale IDs. Allocation/copy/free/cookie and game-array
lookup are captured lower boundaries; allocator layout and all script VM pop/
push paths are not claimed. Outputs `native-module-tag-add-observations.json`,
`module-tag-add-native-v3.txt`, `world-template-query-tests-v1.txt`.

## Native string correction

Actual CExoString assignment03d8c0 checks its first source byte even when given
an explicit nonzero length. Leading NUL clears storage; a later embedded NUL
retains the stored length/tail. The typed GFF string bridge now implements this
rule; waypoint assignment and UUID GFF import use it. In particular a UUID
field beginning with NUL reads successfully as an empty string, so UUID load
retains its old state without emitting an invalid-UUID warning.

`inspect-native-gff-string.py` executes actual ReadFieldCExoString1a1130,
assignment03d8c0 and fallback-copy constructor19e620.162 cases cover exact field
type, presence, payload bounds, defaults, extended bytes and leading/embedded
NUL. Only index/field lookup and allocation/free/copy are captured. Malformed
payload cases verify the original reader; the existing JS parser can reject
malformed files before this bridge. Outputs `native-gff-string-observations.json`,
`world-template-gff-string-native-v2.txt`,
`world-template-gff-string-tests-v1.txt`; the initial uncaptured fallback helper
was investigated and included before PASS. No general VM-string rewrite is
claimed by this increment.

## Installed and regression checks

`probe-installed-world-templates.mjs` passes with active installed
nw_mapnote001/nw_post001/nw_waypoint001 (references discovered by type, without
implementation-specific asset names). Canonical objects574/575/576 load, move
from Prelude area1 to37 and are fully destroyed. Spatial/list/tag membership
and AI exclusion are checked. In-memory typed resolver fixtures577/578 check
orientation, localized values, requested-vs-authored template names, locals,
duplicate/NUL tags, UUID collision ignored by the outer owner, note retention,
null-area removal and retained historical tag IDs. Fixture579 checks leading-NUL
GFF tag/UUID/local-string behavior and the two empty-tag query gates. Missing
template580 is diagnosed and destroyed through the actual lifecycle. Startup/AI
disabled. Exactly one expected UUID warning, one expected missing-resource
error and its template warning are retained. Original authored callbacks and
resources are unchanged. Output `installed-world-templates-v1.json`,
`world-templates-installed-v3.txt`. The installed UUID NCS/VM regression also
passes (`world-templates-uuid-regression-v1.txt`).

All1,712 tests pass (`world-templates-full-tests-v3.txt`); production build passes
(`world-templates-build-v1.txt`, existing bundle warning). Owned offscreen
casting/counterspell/radial/hotbar/animation regression and actual body-bag
radial/use/script/transfer/render regression pass
(`world-templates-casting-regression-v1.txt`,
`world-templates-body-bag-regression-v1.txt`). All owned tests reached terminal.

Engine243 **remains unbound**. Complete UTP/UTM data adapters, remaining creature
creation details, item/world bridges and map-pin transport/presentation still
need work before claiming complete CreateObject or additional playable spells.
Structured variable/JSON/solver gaps remain tracked. Broader combat and campaign
completion are unproven. Checkpoint target
`backups/world-templates-1712-20261016-v1.zip`, verification log
`backups/animations/world-templates-checkpoint-v1.txt`.
