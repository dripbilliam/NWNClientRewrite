# NWN-54 bounded dense-scene source audit

This read-only pass sought one independent, low-risk repeated load or frame operation. It did not produce a production change or timing claim.

* `systems/native_render/area_stream.gd:159-177` still receives `_process` after `done` because static scenery groups can remain pending after tile publication. Its `poll_definition()` runs before the `done` return, but the task state and possible late group flush make process suspension a lifecycle change, not a standalone no-op removal.
* `systems/native_render/live_world.gd:691-833` runs motion, collision sync, streaming priority, admission, pose and combat each frame. It builds and sorts adoption candidates even when batches are empty, but empty list sorting is a tiny call; the meaningful scan and motion paths have separate active work or scheduling tickets. Skipping only the empty sort would not address the measured 3.9 ms particle callback, 146 ms world-commit tail or 75 ms asset callback in NWN-54.
* `systems/native_render/resource_pool.gd:79-123` resets publication counters once per engine frame, then checks the shared completion/publication budget at each consumer. Repeated calls carry the budget contract; removing them without a single owner for all publishers could change first-use and readiness order.

The issue's latest Arelith review reports different route mixes and no dependable busiest-hub FPS gain. A source-only change here would not establish a dense-scene improvement. The next useful gate is a matched normal-client capture that identifies the exact callback and owner during a remaining stall, followed by a scoped source change and cold/warm plus visual-completeness checks. This pass leaves NWN-54 In Progress.
