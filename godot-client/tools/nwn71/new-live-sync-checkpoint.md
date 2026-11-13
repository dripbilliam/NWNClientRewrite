# NWN-71 two-trace Arelith sync checkpoint, 2026-11-12

Status: read-only Tracy analysis. The blocking **group/task identity remains unresolved** in these two captures; no engine/client source change, build, client launch, FPS benchmark or fix was made. The issue remains In Progress.

## Input identity and method

- Control `control-live.tracy` SHA-256 `580a7b16ccfda71bff428815e1a301ef3976a16074a60ce3fe1403d8387a4d10`; candidate `candidate-live-20261112.tracy` SHA-256 `527b0b7ad09fa9ab2368bef34834060ecf4d951a5700641b1d2a26fc8a66ea02`. Both launch receipts identify Tracy engine SHA-256 `899188653385916703da1478bbac088dcd237fda51e14780da40ff491ac77647` and the same expected main source identity `e2b0aa425105b9a2f1889a92cd4769db279dc865d9642d5e8e01fcca10908d20`.
- Existing exports: `.cache/native-tracy/arelith-review-cache-a/{control,candidate}-live-review-20261112/events-review.json`. The official Tracy 0.13 CSV exporter was run sequentially on each saved trace, with process and byte bounds; receipts are `.cache/nwn71/live-worker-20261112-{control,candidate}/receipt.json`. The reducer scanned 210,540 control and 276,435 candidate worker task scopes. Worker/wait JSON hashes: control `8dc987562228c91360eb50da4b0a797940a5253b8396c767040f53bb9c4bb5de`, candidate `b1e536e6ad0ad46c3a5515d5915c8cce06a33f7fb4f3584bfd01286b243dd663`.
- `tools/nwn71/review-new-live-sync.cjs` joins main sync, render draw and render-thread group waits only by exact absolute interval intersection, after correcting for each capture's first-Main-frame time origin. Result `.cache/nwn71/new-live-sync-20261112-b.json` SHA-256 `a6dec6252f977612176eb76bdfe20e773073369b9b0c3da1c31a72664e56060e`. Its retention threshold is 0.25 ms and none of the group/task wait lists hit their 128-row cap. Spans overlap; their durations cannot be added.

## Long sync families

| Trace / relative start | Main sync | Overlap with render draw | Overlap with render group wait | Reading |
| --- | ---: | ---: | ---: | --- |
| Control 149.205 s | 58.890 ms | 58.789 ms | 35.775 ms of 58.063 ms group wait | Render group dependency contributes substantially. |
| Candidate 32.642 s | 59.580 ms | 59.557 ms | 40.975 ms of 49.580 ms group wait | Render group dependency contributes substantially. |
| Control 271.564 s | 74.618 ms | 74.444 ms | 0 | Long draw body, with no retained worker group/task wait at or above 0.25 ms. |
| Control 271.512 s | 50.903 ms | 50.895 ms | 0 | Same distinct draw-body family. |
| Candidate 167.332 s | 47.226 ms | 47.052 ms | 0 | Draw-body family also appears later in candidate. |

Candidate startup at 0.069 s has a 69.055 ms sync, 69.040 ms render-draw overlap and 39.087 ms group-wait overlap. Several other 49–58 ms candidate syncs within the first second have large group-wait overlap. The existing `slowestFrames` export marks these transition/startup tails `world=false`; they are **not** steady Arelith gameplay-frame measurements. Control 149.109 s has a 65.316 ms sync but only 11.576 ms group-wait overlap among the retained top zones; it remains unattributed beyond that. The two live routes and trace durations differ, so this table is not a matched control/candidate regression claim.

## Why the task cannot be named from these captures

Every retained worker wait has an empty ZoneText value. The accepted Tracy engine source at `core/object/worker_thread_pool.cpp:59,409,734` emits generic `task_scope`, `wait_task_scope` and `wait_group_scope` zones without pool, group, task ID or description. The source has three render-path group-join call sites: visibility cull and scene cull in `renderer_scene_cull.cpp:3424,3531`, and shader variant compilation in `shader_rd.cpp:744`. These traces include no inner scene/cull/shader zone or call-stack identifier to choose among them.

An additional read-only task-scope export around group waits of at least 20 ms found **60** unlabeled tasks overlapping the control 58.063 ms group wait and **38** overlapping the candidate 49.580 ms group wait. Some task scopes span hundreds of milliseconds across unrelated work, including the render server's long-lived task, so time overlap cannot prove group membership. Reports: `.cache/nwn71/live-worker-20261112-control/task-overlap.json` SHA-256 `642b92328923bf6eab49d81f3ddd4f29abfc398e31c04a3d7f347ac6d6ee4bc8`; candidate `f92c20e61fb1ab0953986317d1c2fbda01a30df4ea69a73f26a932de43b41989`.

The prior labeled private captures prove that ShaderCompilation and pipeline driver calls can cause separate first-use waits, while the gamma callback can move a first-use hitch. Those mechanisms are **not assigned** to these new waits. The next diagnostic must use an engine that records exact pool+group/task IDs and descriptions on both join and producer scopes, plus nested scene-cull, ShaderRD and compositor callback phases. Then join the same transition frame by exact ID and measure first-playable/fully-loaded and normal-build frame intervals before choosing a fix. A new unlabeled whole-client FPS comparison would not resolve the producer.
