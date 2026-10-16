# Timed object visual data, assignment and runtime ownership

Target: NWN:EE89.8193.37-17, read-only
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original resources/processes and Ghidra database entries were not modified.
All special module/template fixtures stay in memory. Captures contain derived
metadata and synthetic values, not game assets.

## Timed values and transform loading

`src/object_visual_transform.js` ports complete curve load1402e9ef0..1402ea10d,
timer restart1402ea120..1402ea248, its2ea110 tail thunk, and ten-property load
14048f8c0..14048fe10. Full assembly is in
`backups/animations/object-visual-curve-owners-v2.txt` and
`object-visual-load-lower-v1.txt`.

A scalar FLOAT read wins over a same-named nested structure. The structure
reads TimerType, ValueTo and LerpType; only nonzero LerpType admits ValueFrom,
duration, progress, BehaviorFlags and RepeatsRemaining. The last two reads
really occur, but their results are discarded and fields18/1c are zeroed.
Failed direct reads can supply the fallback for ValueTo, while ValueFrom keeps
the original caller default. Output storage is caller-owned: inactive real-time
clock slots20/30 retain their previous bytes. World-time slots28/38 are reset
by the loader. This is not a constructor that zeroes a fresh64-byte block.

Restart is skipped for lerp0 or equal endpoints. Timer0 reads the monotonic
microsecond clock, multiplies duration by1000 twice with FLOAT rounding at each
step, performs the original unsigned64/SSE conversion and wraps addition.
Timer1 obtains the world timer, converts duration to its time-of-day delta,
reads stored world time and adds day0/deltaTime through the existing world-time
owner. Missing world timer preserves clock state; failed addition leaves its
output untouched. Other timer IDs leave both domains untouched. NaN equality,
negative duration, conversion overflow and uint64 wrap are covered.

The ten values load in this native order: AnimationSpeed, ScaleX/Y/Z,
RotateX/Y/Z, TranslateX/Y/Z. Speed and scale default1; rotation/translation0.
One scratch curve is reused. Each loaded value restarts in temporary storage,
is copied to its640-byte transform member, then restarts again. Both timer
queries and their order are observable. Inactive scratch clock fields can
survive after a preceding active value; they must not be mistaken for active
timers. Arbitrary uninitialized stack bytes are not modeled as deterministic
game data. Tests explicitly seed the caller-owned scratch/output storage.

`visualTransformClockProviders` uses the session's local monotonic epoch and
existing WorldTimer/secondsToWorldDelta/addWorldTimes owners. It introduces no
snapshot when reading time. Actual day rollover and paused-time behavior have
an additional concrete bridge test. Existing non-advancing/infinite world-time
conversion checks remain diagnostic failures rather than hanging the client.

`inspect-native-object-visual-transform.py` executes all these original bodies
across474 fixtures. Typed GFF readers and clock/world-time methods are captured
boundaries. Every output byte and read/default/clock call order is compared.
Captures: `native-object-visual-transform-observations.json`,
`object-visual-transform-native-v2.txt`, `object-visual-transform-tests-v4.txt`.

## Scoped maps and assignment

The same module ports complete LoadVisualTransform140497bb0..140497dec and
SetVisualTransform14049c020..14049c163, plus default-map496290/4961c0/496170
and equality48aef0 behavior. Assembly:
`placeable-template-tail-owners-v1.txt`, `object-visual-load-lower-v1.txt`,
`object-visual-transform-equality-v2.txt`,
`object-visual-transform-assignment-heads-v1.txt`.

A present VisTransformList takes precedence over legacy VisualTransform even
when empty. INT Scope defaults0; duplicates load into the same value and the
last row wins. Traversal/assignment uses signed-key order. A failed element
emits the native LoadVisualTransform assertion and discards the whole temporary
map, retaining assigned object state. The temporary map is released after
normal assignment or assertion failure.

The original default-map predicate is all-zero defined curve fields, ignoring
scope keys and clock caches. It is not identity scale/speed1. An absent owned
map therefore stays absent for an empty/all-zero input. Existing maps compare
size, keys and ONLY each curve's ValueTo. Changes to From/interpolation/flags/
clocks alone do not replace the owned map. NaN destinations compare unequal
even when the exact same map is supplied: the leaf's first pointer comparison
is iterator-versus-end, not a map-identity shortcut. That distinction was
caught by original execution and fixed before final validation.

On a change, a missing owned map is constructed and other-map input is copied.
The item cast is queried twice. A valid possessor creature and equipment slot
16/32 copy the incoming map to creature membersab0/ac0 respectively. Other
slots, missing possessors and failed casts do not propagate. Map copies own
their values and do not allocate/change canonical game object IDs.

`inspect-native-object-transform-map.py` executes the original scoped loader,
setter and default/equality functions across399 fixtures. Synthetic valid BSTs
support the original iterator/search logic. Standard-map allocation/insertion/
copy/clear/free, typed GFF reads, the separately tested value loader, item cast
and creature/equipment lookup remain captured boundaries. The cast returns a
distinct synthetic item pointer, so field3c8 and equipment lookup cannot silently
use the base-object address. This does not port/claim STL balancing or OOM.
All defined fields, every copy/cleanup/assert/cast call, map alias behavior and
both equipped-hand branches are compared. Captures:
`native-object-transform-map-observations.json`,
`object-transform-map-native-v4.txt`.

Earlier partial captures stopped at missing unwind metadata for48aef0/496170.
The clean v2 leaf CFG capture has both complete verified bodies. Early harness
syntax/test-count issues are corrected; final outputs above are authoritative.

## Concrete runtime and lifetime

`src/object_visual_runtime.js` connects all five serialized visual owners to
canonical ModuleSession records, parsed GFF metadata, logical owned maps/pools,
session clocks and native equipment storage. It reuses the material/replacement/
misc owners from [the previous continuation](object-visual-data-loading.md).
Invalid owners/metadata remain reported and thrown. Assertions are retained
in diagnostics. Scoped transform sampling, shader/texture rendering, custom
cursor/highlight/distance/bubble presentation and non-creature replacement
presentation remain unavailable and produce explicit records when encountered.
Loading their state is not a claim that those systems now draw correctly.

Base visual state is initialized with the observed constructor fields:
empty pools2b8/2c8/2d8, null map2b0, cursor/RGB-1, distance45, UI mask15,
bubble type0/text empty. Native FLOAT268 now has one backing cell shared by
the existing nativeProjectileRange268 bridge and imported VisibleDistance.
Creature ctor37a49f..4cb constructs hand mapsab0/ac0. Creature destruction
clears ac0 before ab0; base destruction releases map2b0 before UUID, then
animation/texture/material pools and bubble text. Evidence is complete ASM in
`object-visual-lifetime-owners-v1.txt`, and existing creature constructor/dtor
captures. Constructor tests validate this subset, not the whole original ctor.
Actual session destruction tests check ordering around UUID, recursive equipped
item removal, shared FLOAT state and unchanged allocation cursor.

Area import now calls this adapter for GIT placeables after ItemList, following
LoadPlaceable4b6637..6678. Other class loaders have separate admission/order;
their general imports are not silently broadened. Full typed UTP/UTM data
adapters and CreateObject243 binding remain unfinished.

## Animation replacement presentation

`objectAnimationOverrides` prefers the owned pool after the data owner accepts
a list. A missing/wrong-type root preserves that pool; a valid empty list stays
authoritatively empty even if old authored/creature data still contains entries.
Legacy parsed-root import is retained until the first actual list load, keeping
existing creature import behavior. CreatureAnimationPresentation uses this
helper for subsequent animation requests. CPU ModelAnimator tests verify
actual played/sampled clips through canonical runtime retain/update/clear
reloads. No forced restart of an already playing loop was introduced.

## Installed and regression checks

`probe-installed-object-visual-runtime.mjs` initializes the active Prelude data
and wizard, with startup/AI disabled for controlled evidence. An in-memory GIT
extension adds ScaleX1.125 to existing placeable ID3; normal area initialization
automatically imports it and records missing presentation. This changes no
original archive, template, script or saved character.

A separate canonical fixture placeable574 verifies nested world-time curves
from day77/time2879900 to day78/time150, shader/texture storage, discarded
behavior/repeat values, no implicit area insertion and destruction cleanup.
Active discovery finds equipped creature158/item160; the item updates its real
owner's independent right-hand transform copy. Player565's owned animation
replacement is retained then explicitly cleared. The cursor stays575 after
fixture destruction. Five additional missing-presentation records are checked,
separate from the GIT fixture's startup record. The first probe assumed the
wizard had a right-hand item; that fixture assumption failed and was replaced
by discovery of an actually equipped active creature, without inventing gear.
Report `installed-object-visual-runtime-v1.json` and log
`object-visual-runtime-installed-v4.txt` PASS.

All1,727 tests and production build PASS. The existing bundle-size warning
remains. Installed waypoint/UUID/variables/area/destruction and rendered
casting/body-bag regressions PASS; all owned processes are terminal. Final logs:
`object-visual-transform-full-tests-v3.txt`, `object-visual-transform-build-v3.txt`,
`object-visual-transform-world-template-regression-v2.txt`,
`object-visual-transform-casting-regression-v2.txt`,
`object-visual-transform-body-bag-regression-v2.txt`.
Verified checkpoint target: `backups/object-visual-transform-1727-20261016-v1.zip`;
terminal verification log: `backups/animations/object-visual-transform-checkpoint-v1.txt`.
