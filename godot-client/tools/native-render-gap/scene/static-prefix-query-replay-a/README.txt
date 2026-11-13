PRIVATE SOURCE ONLY. No Godot parser/native/compiler/runtime or driver activation
has been performed. G/B5 collision semantic acceptance MUST precede use as a
candidate performance diagnostic. This helper cannot authorize a live test slot.

Purpose: retain up to128 actual static_candidates(from,to,radius,exclude) argument
sets during the UNCHANGED original offline movement timeline, then replay that
direct prefix API against fully prepared current live geometry after the original
timeline completes. It does not replay movement messages/request IDs, create or
reuse old query()/query_preview() Callables, walk, predict movement, change Node
poses/camera, mutate authoritative data, or contact a server.

Numbers stay exact in the SAME process:40B per arguments tuple contains six f32
Vector3 coordinates, f64 radius, signed i64 exclude. A separate16B packet retains
the two signed i64 source-lifetime witness values;48B scope retains owner/world
instance IDs, native connection, generation/area and ticket epoch. This targets
the exact pinned real_t32 engine10b, not an arbitrary double-precision engine.
No JSON number is read back for replay. Snapshot hex strings are diagnostics only.

Future private host/source seam API (NOT implemented or activated here):
1. Lazily begin_capture(current_drive_owner, native_session_connection) on the
   first actual ready prefix call, then call capture_query(owner,from,to,radius,
   exclude) before the ORIGINAL function body. Do not change its result/path.
   Capture counts every hooked call, stores only first128 with duplicates/order,
   and reports capped calls explicitly. A scope/lifetime/domain failure invalidates
   the diagnostic without changing original gameplay. No helper per-group hook.
2. After original driver timelineDelivered and its original movement/prediction
   gates pass, visuals complete+settle+scene workers idle, call seal_after_timeline.
   Context is native source-owned, never trusted UI/request JSON: booleans
   offline_replay, timeline_delivered, movement_gates_passed, keyboard_released,
   all_scene_assets_idle; int connection; PackedByteArray camera_signature from
   actual CURRENT native camera/terminal view. Host must recompute that signature
   and these barriers for every batch. Helper additionally reads actual collision
   owner readiness/ticket/queues, current motion/received actor state and witnesses.
3. begin_pass(owner,current_context,"prewarm"), then replay_batch(...,1..4) until
   complete. Require natural finish and actor/camera/source/lifetime guards. Same
   corpus prewarm is mandatory. Then begin_pass(...,"measure") and repeat exactly
   the same corpus/order/batch size. At most128 queries per pass, no repeats hidden.
4. snapshot returns numeric counts, exact argument digest/hex, scope hex, batches,
   Engine process-frame and monotonic endpoint ticks, bounded exact-result SHA256
   observations. It never sends protocol messages or changes a launcher/setting.

Timing: query_batch_wall_usec covers direct static_candidates calls plus identical
small argument lookup/call/result-slot glue. Record decoding, preallocation,
guards, result serialization/hash and snapshot work occur outside that timer.
Host elapsed/Engine throughput may be recorded separately but are not GPU/display
FPS. This is a loaded-geometry query component diagnostic, NOT fully warmed actor
movement, pathfinding/authority/public-server/native170–200FPS equivalence.

Actual prefix calls update derived binding.world_bounds/bounds_signature, index
last-query diagnostics and profiling counters. Those effects are disclosed and
prewarmed identically. Publication/model/source revisions must remain unchanged.
Permanent catalog-absent PWK/DWK and true error/pending policies are not relaxed.
Actual loaded unready/invalid results reject this clean-cost diagnostic.

Between processes the first128 actual argument sets CAN differ because original
prediction probes depend on frame timing. A causal matched cost comparison MUST
require identical argument count/order/arguments_sha256 (and valid source binding)
or explicitly label separate per-run diagnostics. Never silently retarget IDs,
translate coordinates to terminal actor, or call different corpora matched.

Fixture future CLI, in a fresh pinned capsule after runtime permission:
<exact10b-engine> --headless --path <fresh-private-capsule> --script res://tools/native-render-gap/scene/static-prefix-query-replay-a/fixture.gd -- --report=<fresh-absolute-report.json>
fixture is MOCK codec/ownership/barrier coverage only: signedzero/f64ULP/i64 beyond
JSON precision, cap128/copy isolation, prewarm/measure exact corpus/results,
recursive capture suppression, stale generation/exclusion/connection, queue/
worker/visual/timeline/keyboard/motion rejection, and post-query lifetime drift.
It does NOT prove real collision integration, native G, rendering or authority.

Additional future actual-world obligations: original timeline and terminal actor/
camera gates retained; exact real_t32 engine/native/resource/G module identities;
same current scope/witness; representative query coverage; no engine/script/leak
errors; semantic G+isolated V2/V3 family pass; natural protocol/process closure.
An authored script error can abort GDScript before clearing the replay marker;
runner must reject stuck replay/missing completion and preserve logs, not infer
cleanup/acceptance. This helper is not a general arbitrary-script recovery API.
