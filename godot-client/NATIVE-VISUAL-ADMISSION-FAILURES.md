# Object visual admission and bounded failure handling

Status: scoped implementation/tests pass; full binary-guided streaming,
presentation, repeated transitions and migration remain incomplete.

## Original evidence

Immutable original NWN:EE89.8193.37-17 x64 nwmain.exe SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No original executable, assets or Ghidra database were changed.

The placeable client model wrapper140871440 creates CNWCAnimBasePlaceable via
1409b1fe0, whose vtable is140e78250. Slot18 at140e78268 points to1409b2630;
slot10 at140e78260 points to140964690. The wrapper's virtual load call140871635
checks failure and returns without its later owner/type bindings.

The complete lower loaders have matching explicit failure boundaries:

| Owner | Complete analyzed body | Model creation / null branch |
|---|---|---|
| Placeable |1409b2630..1409b28a2 |1409b27fd calls NewCAurObject1400931f0;1409b280c skips resref commit/reset on null |
| Door |1409b0cf0..1409b0f73 |Only modeFF attempts;1409b0ece calls NewCAurObject;1409b0edd skips commit on null |
| Trigger |1409b16d0..1409b1942 |1409b189d calls NewCAurObject;1409b18ac skips commit on null |

Each attempted loader writes its returned model into owner+C8. On null it leaves
the prior resref at30 and scalar44 unchanged, returning false. Success assigns
the requested resref and resets44. This is not evidence that old model pointers
are retained by these exact functions. NewCAurObject's lower parser/cache and
world-level replication caller failure policy are separate boundaries.

Fresh derived dossiers in `backups/animations`:
`rea-world-placeable-visual-admission-v1.json`,
`rea-world-placeable-model-wrapper-v1.json`,
`rea-world-placeable-animation-constructor-v1.json`,
`rea-world-door-visual-admission-v1.json`,
`rea-world-trigger-visual-admission-v1.json`. Full displayed pseudocode/assembly
and relation limits are retained; duplicated raw results/high-pcode are excluded.

`scripts/inspect-native-world-visual-admission.py` executes all three unchanged
loader bodies in isolated Unicorn. NewCAurObject, CResRef assignment and the
return-preserving security-check helper are explicit captured lower providers;
instrumentation flags are disabled in emulated memory.54 cases cover three
resrefs, success/null results and three modes.42 attempts include21 null cases;
12 non-FF door cases do not attempt creation. Resref/scalar/model-slot and exact
lower call sequences are asserted. Output: `native-world-visual-admission-v1.json`.
This does not prove the complete original retry, cancellation or world policy.

## Godot implementation

Static object streams preserve all existing strict `stats.errors` diagnostics
for captures and other consumers. They additionally distinguish `scope_errors`
(required tables) from per-ID `object_failures` (appearance/model/template/clone).
Grouped model failures identify every affected object, never just one group name.

The live world now isolates placeable/door visual failures from required world
failures. Other valid objects keep loading and an already admitted player keeps
input. Each failed appearance key remains in `failed_objects`; unchanged raw
snapshots cannot requeue it every frame. An appearance change or removal followed
by recreation clears the binding and permits a new attempt. A failed replacement
keeps the previously admitted model until a valid replacement can publish.
Late failed results recheck current appearance keys and are rejected if stale.

These are adapter ownership/retry choices based on the evidenced per-owner
failure boundary, not a claim to copy the original retry algorithm. No missing
visual is silently accepted, replaced with fabricated geometry or counted as
hidden/installed. Diagnostics and the onscreen failure count expose it. Existing
actor/required-table failures remain fatal; this is not blanket optional handling
for player, remote creature, item, terrain or corrupt protocol state.

World removal also clears invisible object bindings, which have no physical
instance to trigger the ordinary removal loop. Close clears failed bindings.
`object_visuals_complete` requires all desired object models or authored invisible
objects, no failed bindings, no fatal error and no pending batches. Native shutdown
records `playable` separately; successful functional reports require complete
object admission. This field excludes particle/effect/lighting parity and does
not imply full visual fidelity, smooth loading or performance acceptance.

## Verification and limits

- `native-visual-failure-v4`:28 checks. Actual native file-backed authored MDL/
  2DA catalogs, asset workers, template publication and live-world admission test
  missing model/table entry, valid neighbor, invisible door, bounded retries,
  changed appearance recovery, failed replacement retention, stale failure,
  server deletion, required table/player failure gates and owner retirement.
  Required actor failure uses an authored batch result; it is not a full actor
  parser test. Stub player/terrain readiness keeps this fixture narrowly scoped.
- `native-static-pose-failure-regression-v2`:eight native pose/admission checks.
- `native-template-failure-regression-v2`:16 GPU shared-template/private-instance
  checks, including four actual static owners/48 objects and live eviction.
- `native-session-visual-failure-v3`:actual default native launcher on owned
  localhost Prelude, complete20 object/nine-tile admission, native/server movement
  during background loading, explicit finish acknowledgement and workers0.
  This ordinary room contains no injected server asset failure; failure coverage
  comes from the authored actual-worker fixture above.

Accepted runs use normal-heap CDB with four exception traps, unchanged sources,
and no trapped native or engine/lifetime error. First fixture run v1 failed because
its authored rig stub omitted snapshot stats; only its owned test process was
stopped. That retained failure is not promoted to a pass. Original oracle's first
development attempt exposed a captured security helper clobbering RAX; the final
helper preserves it and all54 complete-function cases pass.

No public connections occur. Existing cloud/chunk particle diagnostics remain.
There is no dense-scene FPS gain claim, full moving protocol replay acceptance,
clean cold/warm comparison, repeated real transition/reconnect stress or global
resolution of historical native faults. Cancellation while actual workers remain
in flight and the full original replication failure caller still need tracing.
Continue BINARY-WORLD-STREAMING-GOAL.md; full JS migration/wiki remain later phases.
