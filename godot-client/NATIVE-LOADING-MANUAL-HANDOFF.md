# Manual test follow-up, 2026-10-27

The user is testing the prewarmed build. Keep runtime sources stable and do not
launch GPU comparisons or automated public-server connections during that test.
The previous goal turn produced a saved timing review, not an accepted fix.

## Historical session evidence

`reports/native-loading-manual-handoff-review-v1.json` pins the performance JSONL
for `native-session-1793134320019`. There are 35 observations over three area
generations; 32 report ready. Observed entity peaks are 966 and 483 in the two
populated generations. This is a manually driven session, not a sealed replay.
Its terminal host receipt has nativeExit=0 but no native result; it cannot pass
the existing clean full-session acceptance gate. Preserve that failure.

The largest retained wall interval is 336.349 ms, of which 329.380 ms is outside
instrumented callbacks and 6.969 ms is the callback envelope. Async render counters
on that row are CPU 2.584 ms and GPU 1.530 ms; all five pipeline deltas are zero.
These counters do not prove the rest was idle, nor identify its cause.

The automatic ready image was last written at Unix milliseconds 1793134363742,
between profile observations 1793134362915 (peak 33.57 ms) and 1793134364928
(peak 336.349 ms). `native_live_world.gd:capture_preview` awaits frame_post_draw,
then synchronously reads the viewport and saves PNG. It records its costs only
in the final report, which is missing here. This is a plausible diagnostic stall,
not proof that the full hitch was screenshot work. Rolling worst frames can
repeat across observations and must not be counted as separate stalls.

The next generation has a separate 60.752 ms peak, including callback envelope
37.923 ms, root 17.693 ms, object stream 16.743 ms, and protocol apply 14.795 ms.
Root and protocol spans overlap; do not add them. The one-time preview cannot
explain every later streaming hitch. Avoid declaring all pop-in solved.

## Next isolated investigation

After the manual test, compare frozen, same-source input with automatic ready
capture on and off; replay already supports `--no-preview`. Correlate explicit
readback/PNG spans with the wall interval after post-draw, without including them
in disjoint callback CPU totals. Preserve full lifetime/error gates and all assets.
If confirmed, keep automatic diagnostic capture out of normal play and retain
explicit capture as an opt-in diagnostic. No renderer or launcher change has
been made based only on this correlation.

Investigate the later protocol/object spans independently using the same frozen
area and content identities. Session/public measurements may locate a problem;
reproducible offline/local receipts are still required before accepting a fix.

## Read-only source follow-up

The 60.752 ms row lacks snapshot_world/snapshot_ui/transition child spans, so
`protocol_apply` must not be relabeled as world snapshot application. That span
wraps all received message handlers. Future attribution needs bounded per-message
kind timing and byte/object counts; no such instrumentation is installed yet.

Likewise object-stream 16.743 ms includes priority refresh, request submission,
template/door construction, private clone, scene attachment and synchronous ready
callbacks. The row's template total is 2.793 ms and clone total 0.412 ms, leaving
most of this owner unattributed. `particle_emitter.gd:_ready` performs private
channel/service setup and can emit the observed warnings during attachment.
This is a candidate boundary to measure, not proof particles caused the stall.
Before changing algorithms, separately time priority/request, door construction,
attachment/ready and final publication bookkeeping. Preserve disabled-particle
preferences and original required ownership rather than dropping emitter nodes.

The user's new session `native-session-1793134452703` was observed read-only while
its process remained responsive. Three recent generation-7 observations at Unix
1793134751367..1793134755405 were ready, with 629–634 rendered/desired entities,
reported FPS 108–182, wall p95 10.812–14.267 ms and rolling peaks 18.917–22.504 ms.
These are short profiled manual samples, not a clean benchmark, whole-session
maximum, repeatable before/after comparison or native-client parity acceptance.
No server input, runtime edit, additional client or GPU benchmark was performed.

## Implemented after the test client closed

The full final native report for the second manual session establishes the
preview's actual readback 14.313 ms and PNG 992.579 ms; the earlier correlation
is now supported by explicit measured spans. Automatic ready preview defaults
off in the native entry. Replay `--preview` opts in, `--no-preview` remains
compatible, and explicit diagnostic capture is retained. Replay receipts record
requested and actual policies separately. A first verification had an obsolete
requested-policy label; the corrected v2 default receipt is authoritative.

`projectile_scene.gd:prepare_model` now checks `has_meta` before retrieving an
optional native scene model. Godot's null get_meta default still emits an error
when the key is missing. Geometry-free original members keep their existing
null/fallback path; no collision geometry is fabricated or discarded.

Current audit `reports/native-loading-optin-preview-audit-v1.json` verifies the
487-check model and 413-check index regressions under normal-heap CDB with clean
full engine/lifetime gates. Both frozen 630-entity area loads finish: default
produces no automatic ready PNG, while explicit opt-in produces one (PNG
1124.874 ms, readback 10.809 ms). The owned headless Prelude load admits all
19 entities and drains workers/finish protocol. Pinned runtime sources match.
No public connection or new original-client comparison was made. These fixes
do not resolve the measured transition/streaming stalls.
