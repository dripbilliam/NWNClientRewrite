# NWN-71 short render-sync audit (2026-11-13)

Read-only scope: current client render-sync call sites and retained live/private traces. No source, engine, runtime or FPS test changed.

The saved Arelith `new-live-sync-checkpoint.md` has 50–70 ms main sync tails overlapping long render draws. Two long waits overlap render worker-group waits by 35.775 and 40.975 ms, while other long draw bodies have no retained group wait. The trace's worker scopes have no task/group identity. `sync-owner-clock-checkpoint.md` proves shader variant group joins dominate some *different offline* draw intervals, but did not reproduce a main sync above 20 ms or assign the live wait producer.

Current GDScript has no repeated `RenderingServer.sync()` or `force_draw()` call in the inspected native-render path. `native_gamma_effect.gd` puts `compute_list_add_barrier` between a midpoint compute dispatch and the tonal dispatch that reads its result, so removing it would lack pixel correctness. The CPU midpoint route is already an opt-in candidate with a prior unexplained access violation and only preliminary timing. `frame_profile.gd` polls a summary task with `is_task_completed` before its completion wait; `close_summary()` waits only when a task remains, and clears that task through `consume_summary()`. These do not explain the render-thread group wait seen in the live trace.

No safe short duplicate-call removal is established. The ticket still needs exact worker group/task identities and a matched normal-client transition tail before an implementation choice. Keep NWN-71 In Progress; do not infer a GPU bottleneck or add overlapping thread durations.
