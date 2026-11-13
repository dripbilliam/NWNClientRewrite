SOURCE ONLY, NOT GODOT-PARSED OR EXECUTED. V1/V2 remain immutable.

fixture-v3.gd is an isolated observation child: one role and one case per process.
It deliberately writes success:false/OBSERVATION_ONLY. A future runner must prove
actual module/engine/source identities, natural exit, logs, and compare baseline
and candidate transcripts before claiming acceptance. Missing actual candidate or
scratch primer is PENDING, never a baseline-substituted pass.

Future CLI (fresh private capsule, NOT authorized to run now):
<exact-engine> --headless --path <capsule-project> --script res://tools/native-render-gap/scene/static-prefix-adapter-oracles-a/fixture-v3.gd -- --role=baseline --case=<case> --report=<fresh-baseline.json>
<same-engine> --headless --path <same-capsule> --script res://tools/native-render-gap/scene/static-prefix-adapter-oracles-a/fixture-v3.gd -- --role=candidate --case=<same-case> --candidate-script=res://tools/native-render-gap/scene/static-prefix-candidate-b/candidate_factory.gd --report=<fresh-candidate.json>

Cases designed (each separate child/role):
ordinary, replace-groups-then-all-far, replace-groups-then-empty,
replace-states-then-all-far, early-query-unready, late-pending,
reentrant-query, erase-current-key-error, clear-origin-error, free-owner-error,
typed-bounds, typed-states, typed-live-groups, readonly-group,
readonly-states, readonly-state, readonly-bounds-scratch,
readonly-state-scratch, radius-object-error, bounds-object-error,
bool-numeric, nan-radius, inf-radius.
Additional legal opaque Object-key lifetime cases: object-key-ordinary,
object-key-replace-final, object-key-unready, object-key-erase-final-error.
The object key has no external strong reference after setup, ticket labels are
plain strings, and key snapshots are plain labels. Replacement clears all LIVE
maps at the last key; the original container/hidden counter/loop-key cleanup must
preserve Object-key PREDELETE relative to group-index PREDELETE. Erasing current
key is isolated as an expected-error comparison, not normal success.

Lifetime indexes have no fixture-owned strong references; their only strong
owners are actual group dictionaries/caller locals/iterators. PREDELETE events
are recorded before/after query return, live-map clear and owner free. This is
essential: V1 setup.spies intentionally holds indexes and cannot prove teardown.
Replacement cases preserve original iterator keys while new LIVE groups are far
or empty; baseline last-scanned local and original-container cleanup are tested.
Early return/pending/normal cleanup are distinct cases.

Scratch priming uses the exact known actual NwnBuiltinLightInputRegistry facade
pattern from light-member-read/fixture-base-safe.gd, not GDScript get(). Native
poll must first produce the defined numeric error on a readonly radius Object;
Dictionary.assign replaces values while preserving its native scratch owner.
Only then is the same map installed as collision bounds/state. The finalizer
mutates a later pending state, and its event timing is compared against actual
baseline. Registry/host teardown occurs AFTER collision cleanup markers.

Compare exact result_bytes, events, post (excluding no identity fields), checks;
require actual positive cursor/scanned/admit coverage separately on canonical V2.
Error cases require baseline/candidate raw error category, order and partial
effects; only deterministic capsule-path/role-line differences may be normalized
with an explicit reviewed map. Do not silently discard errors, unsupported return
types, missing after-call checkpoints, crashes, leaks, or native fallback.
No `_to_string` conversion semantics are invented or used.

Remaining acceptance: actual parser/runtime, new FOR @container stack cleanup,
typed/readonly/custom error paths, owner retirement, native class ABI/real_t32,
module lifetime, actual positive fast route, no script/native leaks. No activation.
