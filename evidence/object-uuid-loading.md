# Persistent object UUID loading and lookup

Target: NWN:EE89.8193.37-17, read-only
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Ghidra HTTP service was read without database edits. No original process or
resources were changed, and no assets copied into the workspace.

## Owners and behavior

`src/object_uuid.js` ports constructor140504d30..4d6e,
destructor140504df0..4ee0, both eligibility overloads140505390..5401 and
140505410..5479, lookup140505ab0..5ba7, LoadFromGff140505710..5aa4 and
TryAssign140505cc0..50602c. UUIDs live in a separate string-to-parent map.
They never allocate or replace a GameObjectArray ID. Eligibility is exactly
types4/5/6/7/9/10/12/13/14. The member overload reads the parent's BYTE;
the static overload compares its full INT argument. Sounds8 and area effects11
cannot carry UUIDs despite having a CNWSObject UUID member.

GFF load: ineligible returns0 before reading. Missing/failed/empty stored UUID
returns1 and retains any prior value. Nonempty data performs a C-string-key
collision check BEFORE parse/format validation. Collision or invalid input logs
the original text and returns0, retaining prior state. Success adds the parent
pointer to the UUID map and stores the full input CExoString, including its
embedded-NUL tail. The lookup key remains the prefix before NUL.
TryAssign has separate warnings, but the same collision-before-validation and
assignment behavior. Neither assignment owner removes an older map key.
Destructor removes only the current string's C-string key, without checking
the identity of the mapped parent. Lookup uses stored length as its empty gate
and otherwise returns the mapped parent's ID without GameObjectArray relookup.

Admission is equality with the native parse/format round trip. The formatter
uses lowercase hexadecimal widths8/4/4/4/12; uppercase, signs, extra zeros,
whitespace and noncanonical separators fail admission. The general parser also
accepts one-hyphen base62 input, but its reformatted text differs and is rejected
by LoadFromGff/TryAssign. The JS predicate is this admission rule; it does not
implement the general native UUID parser or random UUID generation.

## Evidence and lower boundaries

- `object-uuid-ghidra-v1.txt`: Ghidra constructor/destructor/lookup decompiles.
  These truncate or misrepresent some cleanup/result paths; complete ASM wins.
- `object-uuid-lifecycle-owners-v1.txt`: full ctor/dtor/lookup ASM; final request
  for the static eligibility leaf has no unwind entry. The complete leaf is in
  `object-uuid-assignment-owners-v1.txt`, alongside full TryAssign and random
  assignment coordinators. Capturing random owners does not port their behavior.
- `world-template-locals-effects-v1.txt`: full LoadFromGff140505710 first owner.
  `world-template-uuid-gate-v2.txt`: complete member eligibility leaf.
- `object-uuid-validation-owners-v1.txt`: full parser2f0590/formatter2f0900/
  equality504960 and lookup/upsert lower owners, with original warning strings
  and object-type constants. Native CRT/std::stream internals are not ported.
- `object-uuid-parent-lifecycle-v1.txt`: area ctor35a1ae constructs UUID at3b0
  with parent CGameObject+138; CNWSObject ctor48b967 constructs at2e8;
  base destructor48c25f releases UUID after effects/actions and before tail strings.
- `object-uuid-command-v1.txt`: full UUIDManagement14054a330..54a589.
  GetObjectByUUID selector0x382 is decimal898. Pop failure-639, push failure-638,
  otherwise normal UUID lookup and0 result. Other selectors remain unbound.

`inspect-native-object-uuid.py` executes these original owner bodies unchanged.
2,533 cases cover eligibility truncation, constructor/parent, cleanup, lookup,
load/assignment, statuses, collision precedence, empty/embedded-NUL/long strings,
retained prior value and the full898 VM branch including pop/push failures.
Maps, strings, typed GFF and parse/format are captured lower boundaries. The real
equality helper executes against independently supplied round-trip outcomes.
Results: `native-object-uuid-observations.json`, `object-uuid-native-v3.txt`,
`object-uuid-tests-v3.txt`. Earlier warning assumptions were corrected by the
original trace. A mistaken decimal conversion in the initial command fixture
used902, which took the default branch; it was corrected to0x382/898 before PASS.

`inspect-native-uuid-text.py` independently executes full parser arithmetic,
formatter numeric selection/widths, and original equality for2,011 inputs:
canonical/random UUIDs, uppercase, padded/signed/separator variants, base62,
empty, embedded NUL and trailing CR/LF/TAB. Explicit length36 also prevents
JavaScript's `$` anchor from admitting a final newline. Generic C-locale stream
operations and formatter's
final inline string-buffer extraction are captured boundaries. This validates
the admission predicate; it is not native stream/locale/entropy parity.
`native-uuid-text-observations.json`, `object-uuid-text-native-v2.txt`;
third comparison in `test/object-uuid-native.test.js`.

## Concrete runtime wiring and installed verification

ModuleSession owns an ObjectUUIDRegistry, initializes native UUID state for
areas and CNWSObject records, imports waypoint UUID after its existing GIT
data fields, and binds GetObjectByUUID898. `loadNativeUUID` requires exact
GFF string type10; wrong types are a failed native read and retain old state.
Base destruction releases UUID state in the existing object-tail stage.
The parent JS reference is nonenumerable to preserve normal object serialization.
The map contains parent records, not secondary allocated IDs or synthetic tags.

`probe-installed-object-uuid.mjs` passes with real Prelude waypoint25
WP_M0Q1A_M0Q1B, another real waypoint and player565. Typed in-memory UUID GFF
fixtures exercise load, collisions, invalid-uppercase diagnostics, wrong GFF
type, embedded NUL, old aliases and native lifecycle destruction. Real NCS
GetObjectByUUID executes through the active installed nwscript API and VM.
Canonical allocation cursors never change. Output `installed-object-uuid-v1.json`
and `object-uuid-installed-v2.txt`. Initial failed output is retained as
`installed-object-uuid-v1-failed.json` (wrong expected numeric API ID).
Startup/AI disabled; all load diagnostics and the two expected UUID warnings
retained; no post-load error. The old alias retains a historical record/ID;
this does not claim to reproduce reads from freed original native memory.

All1,708 tests pass (`object-uuid-full-tests-v3.txt`) and production build passes
(`object-uuid-build-v2.txt`, existing bundle warning). Owned offscreen Electron
casting regression passes: spellbook, self radial cast, consumption, hotbar
targeting, cast animation, cancellation, counterspell radial/mode/target
(`object-uuid-casting-regression-v1.txt`). All processes reached terminal state.

Remaining: random UUID creation/refresh and other UUID command branches, save,
other object-type data-loader import ordering, script-variable LoadFromGff,
world template adapters and CreateObject243. No broad spell/combat/campaign
completion claim follows from these tests. Checkpoint target
`backups/object-uuid-1708-20261016-v1.zip`, verification log
`backups/animations/object-uuid-checkpoint-v1.txt`.
