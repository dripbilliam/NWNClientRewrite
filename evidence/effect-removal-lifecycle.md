# Shared effect removal and expiry — 2026-10-15

Target NWN:EE89.8193.37-17, installed x64 nwmain.exe SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The original install and Ghidra database were not modified.

## Original evidence and implementation

`RemoveEffectById140498280..1404984aa` copies the full effect with assignment
`CopyEffect140423ce0(flag0)` before calling the removal dispatcher at140498355.
It captures the creator object before that callback. Only callback result1
permits deletion; any other result retains the record and advances the live
cursor. Success re-finds the first full-value equal record using
`operator==140423ac0` at140498380. It can erase an equal replacement while
releasing the original effect, or find nothing after reentrant mutation.
Creature effect-pointer/attribute updates and source-target cleanup still run
after success even when no equal record remains. Success keeps the old cursor;
nonmatches and rejected callbacks advance it. Counts/array are read live.

`RemoveEffectTarget1404986c0..140498852` resolves the target again, requires a
world-object cast, and retains source+170 membership while any live target
effect still has that creator. Otherwise it erases the target ID from the
same canonical NativeIdList already used for created area effects. Counts
above16 use a sentinel search, whose temporary last element is restored.
No separate ownership list was introduced. This change implements cleanup;
complete ordinary ApplyEffect source-target registration remains a separate
open integration dependency.

`UpdateEffectList14049dae0..14049e829` owns a live cursor. The common tail
14049e04a..14049e0b8 compares expiry strictly after its deadline, attempts
ID-group removal and restarts at0 regardless of the removal result. The
tail14049e7d3..14049e7f1 also restarts after a periodic owner ran. The mapped
regeneration and poison/disease branches now return their actual restart flag
to that coordinator. This fixes stale copied-array siblings causing a second
removal callback in the same pass after a parent deferred itself.

Connected in `src/effect_removal.js` and `src/effect_runtime.js`. Handlers run
before erasure and expose native status separately from lower void/bool
helpers. OnRemoveVisualEffect explicitly returns1 at140439aa4 even when the
lower looping-visual search finds nothing. Existing synchronous simple handlers
remain synchronous; real asynchronous engine providers suspend traversal.
Creature attribute changes run after erasure. Current effect-index consumers
derive their indices from the sorted shared array; no new native index cache
or complete pointer-cache initialization implementation is claimed here.
Equipped creator cleanup is an existing local adapter, now respecting retained
callbacks; it is not newly claimed as an independently mapped native owner.

Full-value comparison exposed two old constructor adapter defects: area-effect
and summoned-creature constructors shortened fixed six-string storage to3/1.
Both now write only their owned slots and retain the rest. Unsupported fixed
payload shapes fail explicitly instead of silently failing equality forever.

## Validation and limits

`scripts/inspect-native-effect-removal.py` executes the complete original
RemoveEffectById/RemoveEffectTarget and original assignment/equality code.
The generic UpdateEffectList coordinator also executes for effects without
special periodic bodies. Allocation, base construction, strings, object lookup,
onRemove callbacks and creature pointer/attribute updates are captured provider
boundaries. Their scripted mutations test the coordinator, not real polymorph.

`backups/animations/native-effect-removal-observations.json` contains936 removal
cases and324 updater cases. They cover0/1/2 statuses, same-ID groups, creator
changes, full-value replacements, insertions/reordering/reentrant deletion,
source/target lifetime, lists above16, strict expiry and half-second deferral.
All removal cases are replayed with both synchronous and asynchronous callbacks;
updater cases verify visited records and ordering against original instructions.
The live runtime integration test additionally proves that an expiring linked
group preserves its parent through500ms, removes the sibling, cleans up creator
membership only after final removal, and preserves canonical game-object IDs.
This uses a captured deferred callback, not an implemented polymorph handler.

All1557 tests pass (`effect-removal-full-tests-v5.txt`), production buildv2
passes. Installed script lifecycle reports pass without new phase errors:
negative-levelv5, afflictionv6, regenerationv3 and bonus-featv2. Known loading
diagnostics remain recorded separately. These isolate unrelated AI/startup and
do not establish normal casting, rendering, combat or campaign completion.
The final build's full hidden spell UI smoke passes (`effect-removal-live-ui-v2.txt`):
self/world radials, spellbook, F2 target selection/cancellation, readied slots,
casting animations and counterspell.

Full polymorph remains OPEN: constructor argument/ability selector, active2DA
transformation, canonical equipment merging/restoration, stat/appearance changes,
client message presentation and feat289/right-click cancellation still need
implementation and original comparisons. Other unmapped effects/engine owners,
full combat and continuous base-campaign acceptance remain OPEN. Goal ACTIVE.

Verified source/evidence archive: `backups/effect-removal-1557-20261015.zip`;
entry length/SHA256 verification is reported in `effect-removal-checkpoint.txt`.
