NWN-71 diagnostic task identity

`prepare-group-labels.cjs --label=<fresh>` reads the exact private Tracy source
under `.cache/native-tracy/engine-msvc-a/source` and writes BEFORE/AFTER snapshots
under `.cache/nwn71/group-labels-<fresh>`. It never edits or compiles an engine.
The coordinator applies only the two AFTER files after verifying the receipt's
BEFORE hashes. No scheduling, group layout or accepted normal-engine change.

Existing worker task/wait scopes export `pool` and `group` in ZoneText. Task
descriptions and IDs are copied while the existing task mutex owns the record;
text encoding happens after unlocking. Wait labels use only method inputs.
ShaderRD adds a labeled compile-group wait and a child compile-variant scope.
The worker shader scope never reads the asynchronously published task vector.
Descriptions have tab/newline characters replaced before CSV export. Text
formatting is enabled only while the diagnostic Tracy build is connected.

The official Tracy0.13 CSV export's `value` field comes from ZoneText. ZoneValue
alone would not fix the saved export's missing dependency identity.

`node tools/nwn71/verify-label-contracts.cjs` checks source pins, unedited engine
inputs, and non-Tracy token equivalence under8thread/cache/debug combinations.
`node tests/nwn71_group_analysis_test.cjs` checks exact group joins, nested task
ownership and rejection of unrelated/unlabeled temporal overlap. These are source
checks, not C++ compilation or trace-label runtime acceptance.

`node tools/nwn71/prepare-fixture-view.cjs --label=<fresh>` makes a standalone
project with no autoload or extension. A coordinator-launched engine runs:

```
--headless --path "<fixture view>" --script res://tests/nwn71_first_use_shader_test.gd -- --report=res://sentinel.json
```

This CPU-only mode submits4indexed tasks with2workers and description
`NWN71_ControlledGroupSentinel`, then records the exact returned group ID and
completed indices. The short worker delay gives the profiler an identifiable
group wait. It measures no FPS.

The explicit graphical mode adds `--gpu-first-use` after `--`. Use a real RD
renderer (`--rendering-method forward_plus --rendering-driver vulkan`), a small
window on the secondary display, and the private Tracy engine. The project sets
no_focus. It submits one spatial ShaderMaterial, records the first drawn frame
and a few settled frames, then exits. No shader family or global cache is warmed
by preparation. The shader's cache may already be warm: a missing compilation
group is a negative result, not proof that the area stall is fixed.

After the coordinator saves a labeled capture:

```
node tools/nwn71/export-labeled-groups.cjs --trace=<capture.tracy> --report=<fresh.json>
```

Optional `--start-ns`/`--end-ns` bound the absolute timestamp window. Export is
streamed and bounded, not saved as a full event table. Worker tasks join waits
only by exact pool+group. Shader child scopes join the innermost enclosing task
on the same thread. Instrumented CPU elapsed waits overlap main/render/worker
durations; never add them or infer GPU time. A representative area capture and
normal-engine matched improvement remain required before resolving NWN-71.
