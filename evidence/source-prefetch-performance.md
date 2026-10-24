# Independent scene source preparation — 2026-10-21

Only offline fixtures and the owned local Prelude server were used. No Arelith
connection or input. The broader performance goal remains active.

## Implementation

Previously, scene synchronization completed every object's source reads,
texture decoding, GPU preparation and instance construction before starting
the next object's resources. This left the worker pool idle during waits.

`ResourcePrefetch` now warms at most two independent resource groups alongside
that ordered consumer. It uses the **same owning scene's source cache**, so a
foreground request can bypass the queue or reuse already-started work. Worker
decoding and asynchronous reads overlap while instance creation, GPU template
preparation, fallback/error reporting and logical attachment remain ordered.

The initial controlled object is built first. Newly visible NPC, placeable and
door plans are eligible; creatures retain the existing body's fallback, exact
per-part material colors and PLT candidates, robes, tails/wings and mounts.
Ground/held item existence probes keep their existing consumer path. Existing
bindings are skipped before extra appearance serialization to avoid adding a
second per-frame scan of their full equipment signatures.

Queued plans validate current object identity, area, removal state and source
appearance. Area closure clears unscheduled work, cancels worker decoding,
drains started jobs and releases unused prefetched textures. Equal names from
different scenes/servers never share a cache or queue. No speculative object,
animation, mount attachment, draw, or canonical mutation occurs in prefetch.
Counters are published as `#model-canvas.dataset.resourcePrefetch` every200ms
and included in the existing area worker-retirement diagnostic.

## Validation / measurements

`source-prefetch-regression-v4.txt`:42 tests pass, covering queue bounds,
coalescing, foreground bypass, controlled-object priority, no early GPU/model
instances, stale appearance changes, close/cancel/drain, owning cache isolation,
consumer-owned failures, multipart palette/PLT/fallback/mount plans, existing
scene delivery and graphics/resource retirement, and debug IPC cleanup.

`scripts/benchmark-source-prefetch.mjs` uses production scene synchronization
with24 resources and injected15ms I/O /2ms GPU-prepare waits. Ordered runs took
796/750ms; prefetch runs419/403ms. All24 sources are read once and instances
retain identical ordering, with the controlled object first. These injected
waits demonstrate overlap; they are not measured server or disk latency.

Two production local runs after build `index-DLOh7yhC.js`:

| Local transition to all prepared | Prior run | Prefetch run1 | Prefetch run2 |
|---|---:|---:|---:|
| Request → fully prepared next area |9.63s|5.96s|6.46s|
| Worker/model/asset failures |0|0|0|
| Academy tiles / objects |100 /92|100 /92|100 /92|

Both new runs warmed59 resource groups, peak two speculative groups, with none
remaining queued or running at settlement. Each parsed112 model sources and37
rule tables for that area. The controlled player rendered correctly. Resource
requests were490 per run. Driver-cache state is uncontrolled, so this is not a
guaranteed cold-load ratio. At3440×1369, the local vanilla scene remained around
96FPS after excluding two seconds of resize settling; the detailed proof keeps
each run's measured values. This is a lighter scene than the user reported.

`scripts/verify-source-prefetch-performance.mjs` checks these facts and writes
`source-prefetch-performance-proof-v1.json`.

## Combined rendering workload

The dense fixture now combines1,501 authored solid meshes,63 real point lights,
native keyhole/targeting shaders,15 admitted point shadows and80 production
particle emitters. There are9,760 active particles /58,560 particle vertices,
1,581 main draws /67,522 main triangles, plus711 shadow draws. Resolution is
3440×1369. No installed assets are copied; the native shaders are read in place.

`heavy-renderer-combined-v1.json`: mean22.13ms, p9523.70ms; particle work11.99ms,
camera/light work2.52ms, render submission7.62ms. Zero captured shader/renderer
errors; all80 emitters remain active. This measures the production CPU particle
path and real WebGL drawing together, rather than summing isolated timings.
It does not include all gameplay/UI costs or reproduce the modded server.

The combined workload remains above the16.7ms p95 target. This is direct
evidence that particle vertex preparation is the next off-thread candidate,
while simulation order, RNG, atlas clocks, collision and retirement must remain
correct. Shader warmup and representative animated/local multiplayer stress
testing remain open too. The goal is not complete.

## Debug-window close exception found during testing

The local probes successfully disconnected and saved measurements, then
remained alive during shutdown. Changing the probe from `app.quit` to
`app.exit` did not fix it. An isolated real Electron fixture
(`scripts/probe-debug-window-close.cjs`) captured the actual exception:
`TypeError: Object has been destroyed` in the debug owner's `closed` handler.

The handler read `window.webContents.id` after BrowserWindow destruction. It
now captures the ID while attaching and removes the owner by that saved ID.
The destroyed-getter unit test passes; the real Electron fixture changes from
exit1 /captured exception to exit0 /no exception. This also fixes ordinary
replacement-client shutdown, not just the benchmark harness. No original game
process is involved.

The two local probes carrying the old handler required guarded cleanup of
their verified owned PIDs22360 and52744 after report/disconnect (harness exits
-1). Do not count those as clean process exits. The corrected handler is
verified separately; a later full local run should also verify shutdown.
