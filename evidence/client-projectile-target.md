# Projectile target parts — 2026-10-16

Live projectile paths now use native target-part naming for doors/placeables,
derived from the successfully loaded resource name. The old prefix-unimplemented
diagnostic is replaced by the verified owner. No spell ID/name exception was added.
Full spellcasting, combat and campaign work remains active and incomplete.

Read-only NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install and Ghidra project unchanged. Prior verified checkpoint
`backups/cast-voice-1863-20261016-v2.zip`,9696 files/120681019 bytes.
Verified checkpoint: `backups/projectile-target-1865-20261016-v1.zip`,9732 files,
122154044 bytes; every archived entry's length and SHA256 verified.

## Original owners and types

Setter1409873d0 calls client lookup1406abb60 ->1406d81f0 ->GameObjectArray lookup.
It invokes virtual A0 then28. Verified MSVC RTTI/vtables establish the types:
CNWCPlaceable140e53950 A0->140870b10 returns this; CNWCDoor140e52f68
28->14086df20 returns this. The matching base methods return null; creature
140e474e8 supplies those null methods. These are not guessed casts from offsets.

Placeable field1e0 supplies prefix+`_impact`, overriding any explicit input part.
Door field1c8 supplies prefix+`impc` (exactly four bytes), also overriding input.
Other/missing targets use the supplied counted string or default `impact` when
its stored length is zero. Missing lookup first stores INVALID but shared tail
14098766d overwrites it with the requested ID. Input CExoString is freed/cleared
at the shared tail. JS uses managed strings; no native pointer ownership claim.

Door model loader14086e080 installs its requested model resource name at
14086e2cb..86e2e0 after lower model-load success. Placeable loader140871440
installs the name at14087168c and calls SubString14016c710 at1408716b5 with
start4/count-1, then moves that result into1e0. It removes the first four bytes,
without checking a literal `plc_` prefix. Case is preserved by these owners.
They do not use the MDL's internal root name. Outer load failures leave prior
fields intact; the local bridge records metadata only on a successful instance.

## Implementation and validation

`client_projectile_target.js` ports the setter and name projection using existing
native byte-string helpers. `main.js` records the requested resource name on
successfully instantiated wrappers, including runtime-created placeables.
The presentation bridge resolves current client mirrors, retains requested IDs,
and feeds the resulting name into the existing native path initialization and
per-frame pose lookup. No authoritative object or ID allocation is changed.
An existing render with unavailable name metadata fails explicitly; an object
without a loaded render uses its initial empty prefix. Impact model attachment,
weapon/shield handling and other unrelated diagnostics are retained.

`inspect-native-projectile-target.py` executes the entire original setter, real
type-cast methods via original vtables, and successful loader prefix fragments.
It verifies RTTI and stores the observed vtable methods. Object lookup, allocation,
strings, successful-load admission and scene/model services are captured lower
boundaries; string helper internals and full load failures are not executed here.
`native-projectile-target-observations.json` contains768 cases: missing/creature/
placeable/door, eight model names including short/mixed-case/byte names, loaded/
unloaded states, four part names including embedded NUL, and three requested IDs.
Tests compare prefix, final ID/name and native input cleanup. An integration test
checks both target types' pose queries and resulting path velocity, while
preserving canonical registry IDs. Initial test v1 caught the erroneous five-byte
assumption `impct`; original bytes/capture proved `impc`, corrected before final
validation. Integration test v3 observed velocity before native first motion;
v4 samples the normal update and passes. Neither failure was hidden.

All1865 tests and build pass. Read-only installed Prelude entry-area probe finds
all seven distinct loaded models' computed impact nodes (six placeables and one
door). This checks authored model metadata, not a live spell aimed at a door.
Installed wizard projectile UI passes chant, CC8 start/release, conjure/fade/
callback cleanup and projectile travel/impact/cleanup. Screenshot inspected;
existing dark/occluded geometry remains. Electron reports a GPU command-buffer
error after PASS/exit; renderer errors remain empty. Full GPU stability unproved.

## Still open

Native AI impact attachment, weapon/shield result handling, missing-target dummy,
linked/ref-model and scene-hit path builders, child spawns, moving loop audio,
full client packets/scene ownership and remaining effects/engine calls are not
completed by target-part naming. Combat/campaign parity is not yet established.
