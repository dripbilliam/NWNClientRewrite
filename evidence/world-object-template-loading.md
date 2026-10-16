# World-object template loading prerequisites

Target: NWN:EE89.8193.37-17, read-only
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No process changes, original asset copies, or Ghidra edits.

## Verified owners and implementation

`src/world_object_template.js` ports complete LoadFromTemplate wrappers:
placeable1404b4650..1404b48f1, store1404fb960..1404fbbe8,
waypoint140509cf0..140509f73. Full unwind disassembly is retained in
`native-create-object-lower-owners-v1.txt`. Their resource types/signatures are
2044/UTP,2051/UTM,2058/UTW. The wrapper consumes a C string; the command
caller owns the16-byte CResRef limit. Resource loaded status is a nonzero test.
Failure releases the resource before logging the original warning and returning0.
Success obtains the root, invokes the data loader, loads script variables,
releases the resource and returns1. The data-loader result is ignored.
Placeables assign the requested template before the data loader; stores and
waypoints assign it afterward, overwriting the data-loader template assignment.

`src/waypoint_template.js` ports full LoadWaypoint140509f80..14050a462.
The full disassembly is in `native-world-blueprint-load-owners-v1.txt`.
The new-tag override is gated by stored byte length, including embedded NULs.
Otherwise Tag defaults empty. LocalizedName always loads with an empty default.
All six position/orientation FLOAT reads default0. The exact-unit-length check
and Normalize14022db30 preserve float32 arithmetic and its near-unit tolerance;
zero orientation becomes[1,0,0]. Position is stored with flag0 before orientation.
HasMapNote must have successful status and nonzero value; MapNote must also
have successful status before the flags and localized note commit. A failed or
false gate retains old note state on reload. TemplateResRef assignment precedes
module tag insertion, followed by the object's UUID load. The return is always1,
including ignored UUID-load failure.

## Lower-owner identification correction

Following actual direct calls corrected two initial research assumptions:

- Wrapper call140497ba0 is a leaf thunk: add object+108, then jump140507640.
  That full owner reads VarTable, Name, Type and Value; it loads script variables,
  **not saved effects**. Its dispatch includes additional native value types,
  location loading, and JSON. A generic loop over five JS types is not proof of
  parity for this owner.
- Waypoint call140505710 receives object+2e8 and reads UUID. Its gate140505390
  checks owner object type; it is not a script-local loader or feature toggle.
  It checks a persistent string lookup, rejects collisions/invalid input, and
  records a valid UUID separately from the runtime object ID. It does not create
  a replacement canonical runtime ID. Validation, lookup ownership and cleanup
  were subsequently ported; see the UUID continuation below for evidence/limits.

Verified thunk/basic blocks: `world-template-uuid-heads-v1.txt`.
Full VarTable owner: `world-template-variable-owners-v1.txt` first function
140507640..140507ef8 (the trailing request for505390 had no unwind entry).
Full UUID loader: `world-template-locals-effects-v1.txt` first function
140505710..140505aa4 (the trailing thunk request had no unwind entry).
Full UUID gate: `world-template-uuid-gate-v2.txt` leaf CFG390..401.
The failed combined leaf-CFG attempt is retained as
`world-template-uuid-gates-v1.txt`; it is not evidence of complete coverage.
`world-template-gff-readers-v1.txt` records Normalize and typed GFF readers;
FLOAT8/string10/resref11/localized12 require exact field types.

## Original-code comparisons

`inspect-native-world-object-template.py` executes all three complete original
wrapper bodies.720 cases cover resource status0/1/2/-1, lower load0/1/-7,
empty/case-sensitive/over16-byte/embedded-NUL/1252 references, null/empty/tag
overrides, assignment ordering, ignored results, original warnings and cleanup.
Resource parsing and native string allocations are captured lower boundaries.
`native-world-object-template-observations.json` and
`world-object-template-native-v2.txt`; comparison test
`test/world-object-template-native.test.js`.

`inspect-native-waypoint-template.py` executes the entire original waypoint
loader and Normalize body.698 cases cover override lengths, independent GFF
statuses, map-note reload retention, default values, near-unit/zero/nonunit
orientations and150 deterministic random vectors, tag insertion and UUID-load
ordering. GFF readers/string copies/UUID/tag-table internals are captured lower
boundaries. Outputs: `native-waypoint-template-observations.json`,
`waypoint-template-native-v2.txt`; comparison test
`test/waypoint-template-native.test.js`. Combined tests pass in
`world-template-tests-v3.txt`. Earlier test failures are retained: wrong native
warning assumptions and a mistaken expected case count, respectively.

## Remaining runtime boundary

Waypoint adapter continuation: active UTW template/data/variable/UUID providers,
area insertion and cleanup now work through canonical runtime owners. Tag-query
and explicit-length string ownership were checked further and corrected. See
[concrete runtime evidence](world-template-runtime.md). Engine243 is still
unbound; complete UTP/UTM/other bridges and map-pin delivery remain open.

Variable continuation: the full seven-way caller now has an owner port, and
primitive/location typed imports are wired into fresh game-object loading.
Structured engine loads remain explicit diagnosed gaps. See
[variable loading evidence](script-variable-loading.md) for original comparisons,
retained struct-output behavior and canonical BIC location handling.

UUID continuation: ctor/dtor, eligibility, load/assign and lookup now have native
comparisons and concrete canonical runtime storage, waypoint GIT import and
GetObjectByUUID898. See [UUID evidence](object-uuid-loading.md). Random/save/
other data-loader imports and full script-variable loading remain separate.

These are pure owner ports with explicit providers. Engine243 CreateObject
**remains unbound**. No new spell or right-click action is claimed playable by
this increment. Concrete UTP/UTM field loaders, typed GFF adapters, UUID adapter
use in new templates, VarTable loading, lifecycle bridges and map-pin delivery
remain required.
The existing canonical constructor, destruction and area-owner work remains
intact. Static API presence audits cannot establish these lower branches.

All1,705 tests pass in `world-template-full-tests-v1.txt`; the production build
passes in `world-template-build-v1.txt` with the existing bundle-size warning.
No renderer changes were made in this increment. Checkpoint target:
`backups/world-template-1705-20261016-v1.zip`, verified by
`backups/animations/world-template-checkpoint-v1.txt`.
