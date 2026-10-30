# Engine frame attribution and rejected packed summary candidates

Goal2 investigation, 2026-10-27. Renderer/default methods and Compact scenery's
opt-in policy are unchanged. This adds diagnostic observations, not native-client
performance parity. No public-server connection or original-binary change.

## Installed engine boundary

The local API inventory is `reports/native-performance-goal2-engine-api-v1.json`.
Godot reports4.7.2-stable, build hash
ed1daf0bf001b61586d9930840f2f1394092c079. RenderingServer exposes
get_frame_setup_time_cpu and draw signals. The
[official API](https://docs.godotengine.org/en/latest/classes/class_renderingserver.html#class-renderingserver-method-get-frame-setup-time-cpu)
defines milliseconds and global scope across viewports. The
[matching engine source](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/rendering_server_default.cpp#L72)
places this counter around scene/canvas updates, after rasterizer begin and before
viewport drawing. It is not a complete engine-frame or CPU-cycle measurement.

The profiler additionally timestamps frame_pre_draw through frame_post_draw,
recording render_frame_wall_ms and the setup reading at that boundary. The existing
postdraw_ prefix associates these spans with the next collector wall interval.
No force_sync is added. This is a wall interval including relevant render waits,
not another disjoint callback CPU owner. It excludes bookkeeping after the
post-draw signal. Asynchronous viewport/GPU readings are still not assumed to
identify the same completed GPU frame. Setup is also recorded as render_setup_cpu_ms.
Options Performance displays setup and the rendering interval.

## Runtime checks and measurements

The first headless API fixture waited for a draw signal that headless never emits.
Only that uniquely identified owned process was terminated; the failed receipt
is retained. The corrected bounded tests distinguish real graphical boundaries
from headless absence and verify disabling profiling stops new samples.
`native-goal2-render-boundaries-headless-v2` and
`native-goal2-render-boundaries-graphical-v1`:11 checks each under CDB, clean.

`native-goal2-render-boundaries-area4-v1` completes all630 captured entities,
clean engine/lifetime gates, workers joined and source unchanged. Its largest
sampled wall interval61.609 ms is dominated by callbacks60.659 ms, with the draw
boundary0.752 ms and setup0.009 ms. A later snapshot reports profiler summary
10.866 ms. Final sampled rolling mean wall5.876 ms, outside callbacks2.698 ms,
draw boundary2.299 ms and setup0.165 ms. These figures overlap; do not add them.
The earlier manual dense room's100–140 ms unassigned stalls are not reproduced
or explained by this smaller isolated area.

## Rejected pure GDScript packed-statistics attempts

The previous summary algorithm is pinned from authored checkpoint
native-loading-compact-options-v1.zip. Both candidates preserve exact field order,
f64 row-order sums, sparse counts/denominators, p95/max, worst-frame ties and
empty windows on33 checks. The first rescans rows into packed columns; the second
uses single-pass reference-owned columns. Both are slower on the synthetic
240-row,161-field workload (three warmups, ten measurements):

| Receipt | Prior mean ms | Candidate mean ms |
| --- | ---: | ---: |
| native-goal2-frame-statistics-v1 | 14.503 | 19.264 |
| native-goal2-frame-statistics-v2 | 14.856 | 19.308 |

These are CPU diagnostic timings, not game FPS acceptance. Production retains
the original calculation. The v1 authored helper is retained at
reports/native-goal2-frame-statistics-v1.candidate.gd; the v2 implementation and
oracle fixture are in verified archive native-goal2-packed-summary-rejected-v1.zip.
Next investigate bounded data-only worker summaries or an exact compiled path,
including stale-result rejection, nonblocking presentation and shutdown ownership.
