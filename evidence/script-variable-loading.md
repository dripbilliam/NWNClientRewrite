# Script-variable GFF import and location storage

Target: NWN:EE89.8193.37-17, read-only
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Ghidra was read without database edits; original installation and processes
were not changed. Installed resource fixtures stay in memory, without asset copies.

## Owner ports

`src/script_variable_load.js` ports complete LoadVarTable140507640..140507edc
(the7-entry jump table begins atedc). Full original ASM is the first owner in
`world-template-variable-owners-v1.txt`. The final extra request in that capture
failed to find an unwind entry; it does not truncate the preceding full owner.
Ghidra output `script-variable-load-ghidra-v1.txt` stops at the first free(NULL)
and cannot establish complete control flow. The ASM controls this port.

GetList(VarTable) must succeed; list rows overlay existing typed cells without
clearing the table. Name is CExoString10/default empty; Type is DWORD4/default0.
Unknown type selectors are ignored. Values use exact field types:

| Local type | Value read | Default |
| --- | --- | --- |
|1 int|INT5|0|
|2 float|FLOAT8|0|
|3 string|CExoString10|empty|
|4 object|DWORD4|0, **not INVALID**|
|5 location|STRUCT14, then LoadLocation|see below|
|6 Cassowary|STRUCT14 and engine load/set|explicit lower boundary|
|7 JSON|STRUCT14, constructor, JSON string10 and parse/set|explicit lower boundary|

Type1 calls SetInt1405086e0 with loading1. Types2/5 have inlined map writes;
their default-valued cells are removed while retaining other types under the
same name. Object IDs are stored raw by this owner; BIC rebasing belongs to its
separate importer. The type6 solver branch **falls through** into type7 JSON
loading; no jump follows the solver destructor at140507daa. JSON is parsed
only if its string read succeeds and its stored byte length is nonzero.

Native GetStruct1401a04e0 does not write its output on failure. Each of the
location/solver/JSON cases has a separate CResStruct stack local reused across
iterations. A failed later read therefore retains the preceding successful
struct for that same branch. The port preserves that behavior. A first failed
struct read depends on uninitialized native stack contents; the concrete client
records and stops that import instead of claiming to reconstruct those contents.

LoadLocation1402e9830..1402e99a1 reads DWORD Area/default0, then
FLOAT OrientationX/Y/Z and PositionX/Y/Z/default0. It copies native XYZ without
normalization, coordinate conversion, area lookup or ID allocation.
GetLocation140507510..140507564 returns an owned areaINVALID/zero-vector
structure for an absent local. A stored invalid-area location with any nonzero
position or facing component is retained. `src/script_variables.js` fixes the
earlier area-only deletion test and null getter default. Empty location clears
only its typed cell. The seven typed cells now participate in name pruning;
opaque nonempty solver/JSON values cannot be discarded by deleting an int.

`src/native_gff_fields.js` admits exact parsed field widths, using retained GFF
metadata. Wrong types return native defaults/status0. Missing metadata for a
present field is a diagnosed unavailable boundary, never a guessed width.

## Concrete import wiring and remaining lower owners

ModuleSession's fresh parsed variable imports now use the typed path for module,
area/GIT records, inventory items, UTI template loading and UTC loading. One
whole row array is processed together so retained struct locals span iterations.
`register` still accepts explicitly semantic rows from local/test callers;
these are not presented as serialized GFF parity. Non-list VarTable fields are
ignored. The native loading flag propagates to the integer callback. Existing
journal hooks remain partial; no complete journal protocol claim is made.

Cassowary and JSON load/copy/set calls have explicit provider seams in the full
caller port. Concrete imports **diagnose and throw** at these unavailable lower
owners rather than silently dropping types6/7. Their actual parsers, solver,
shared-value identity and error/lifetime semantics are still unfinished. Native
empty predicates and lower owner captures are retained for that continuation:

- `script-variable-load-lower-v1.txt`: LoadLocation, SetInt, MatchIndex,
  DeleteIndex, SetCswy and SetJson owners plus switch table.
- `script-variable-structure-owners-v1.txt`: GetLocation, solver ctor/load,
  JSON ctor, name lookup and map insertion owners.
- `script-variable-structured-empty-v1.txt`, `script-variable-json-empty-v1.txt`:
  solver emptiness checks actual internal lists/counts; JSON emptiness tests
  native JSON type0, not generic truthiness. False/0/empty array/object are not null.
- `script-variable-json-parse-v1.txt`: JSON parse-wrapper and shared assignment;
  native parser and exception behavior still need complete ports.
- `script-variable-gff-admission-v1.txt`: exact DWORD4/INT5/list15/struct14
  admission and untouched struct failure output.
- `script-variable-name-hash-v1.txt`: name hashing uses the stored byte length.
  The native lookup separately compares length plus C strings. Full hash/bucket
  behavior, especially embedded-NUL names, is not proven by a JS Map or this
  caller oracle. Name matching in ordinary case-sensitive names is covered.

BIC object-ID remapping remains separate. Saved area references cannot currently
be rebased into a newly loaded module. The importer now clears that location cell
before retaining its existing diagnostic, avoiding accidental aliasing with a new
area having the same numeric ID. Other typed cells remain intact. BIC structured
locals also produce explicit diagnostics; no cross-module location parity claim.

## Verification

`inspect-native-script-variable-load.py` executes original LoadVarTable,
LoadLocation, GetLocation, MatchIndex, DeleteIndex and SetInt bodies.237 cases
cover defaults/typed mismatches, shared-name overlays and removal,100 seeded
12-row sequences, object0/INVALID, nonunit/invalid-area location vectors, owned
empty getters, solver-to-JSON fallthrough, JSON gates and repeated failed struct
reads. Map lookup/allocation, structured load/copy/set, GFF payload access and
hashing are explicit captured lower boundaries. The table has no creature pointer,
so original journal side effects are not claimed. Stack locals are deliberately
zero-seeded; first-failure values are controlled fixture inputs, not a claim
about original uninitialized memory.

Final outputs: `native-script-variable-load-observations.json`,
`script-variable-load-native-v3.txt`, `script-variable-load-tests-v3.txt`,
`test/script-variable-load-native.test.js`. Initial expected row count was wrong
and corrected. The initial GetStruct fixture wrongly cleared failed outputs;
the corrected final trace retains them and adds repeated-row checks.

`probe-installed-variable-load.mjs` passes with real Prelude waypoint25/player565.
The loaded Prelude GIT records have0 serialized variable rows; the probe therefore
discovers an active blueprint dynamically. Its first eligible resource,
UTC x3_antoine, has2 authored rows and loads through the same concrete provider.
No resref is hardcoded into implementation or fixture selection. In-memory typed
fixtures then exercise all five local query APIs through actual NCS, active
installed nwscript definitions and VM. They verify loading1, independent cells,
wrong-width defaults, object IDs, retained invalid-area locations, retained prior
struct output and owned empty getters. Canonical allocation cursors stay fixed.
An in-memory wizard BIC inventory fixture uses saved Area1 while the new module
also has Area1: its imported local is cleared/diagnosed and cannot alias that area.
The two structured gaps and first-uninitialized-struct gap are deliberately
exercised, with all three failures retained. Original authored callbacks/assets
are unchanged. Startup/AI are disabled. Output `installed-variable-load-v1.json`,
`script-variable-load-installed-v5.txt`; initial failed NCS fixture is retained as
`installed-variable-load-v1-failed.json` (a nonzero object constant means INVALID;
the corrected fixture uses OBJECT_SELF with the waypoint as frame self).

All1,710 tests pass in `script-variable-load-full-tests-v3.txt`. The production
build passes in `script-variable-load-build-v2.txt` with the existing bundle-size
warning. Final owned offscreen Electron regression passes spellbook selection,
self radial casting, slot consumption, hotbar targeting, casting animations,
target cancellation and counterspell radial mode/target
(`script-variable-load-casting-regression-v2.txt`). All processes reached terminal
state. Checkpoint target `backups/variable-load-1710-20261016-v1.zip`, verification
log `backups/animations/script-variable-load-checkpoint-v1.txt`.
Engine243 CreateObject and broader spell/combat/campaign completion remain
unproven and unfinished.
