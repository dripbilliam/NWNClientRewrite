# NWN-78 current world-state duplicate-work gate, 2026-11-12

Status: read-only source and saved dense-scene evidence. No production/client edit, build, graphical run, or FPS claim.

## Source and capture pins

- `systems/native_render/live_world.gd` SHA-256 `ec5c12122567a3824650debdc0b212b3a0e2651d20825493ece161ea6bd4f422`.
- `drive_collision_indexed.gd` `f3c2b35e783dd7d0dec24a1978a6f47edc2e3024ef2f37d8b158b6a8cfaca928`; `native_scene_visibility.gd` `88058dc0e13f7e95368bb701427c7cf34cbbf544990bf0088a47ba13955f599b`; `scene_query_index.gd` `0b17ff7cbcf34c8cdc3492e804dc73c2f6ceb5eca9d83f1d9738064d91e996dd`; `area_stream.gd` `100b5e653b36765a049c90253c53e559006e67956ec78c4874667fd3e0cc508f`; `resource_pool.gd` `cb702ea11b45251078de8fa1b8cfd16a486f2dac030aabdd750a33a21e1f39b2`.
- Saved original-scene instrumented profile: `reports/nwn74-forward-census-d.performance.jsonl`, SHA-256 `77884899f548d24b237611f08eb639b25731fe007994ef88ce869babe0fd9c4`. The capture's `drive_collision_indexed.gd` and other source pins may differ from the above current workspace; its timings are provenance-bound bounds, not current-source benchmarks.

## Ownership and recurring traversal

The saved settled scene held 1,918 installed world objects, about 59,620 Nodes and 752 Resources. Current `live_world.gd` calls `motion.update`, collision `sync_motion`, `apply_poses`, combat update, and motion finish per frame. The captured motion/pose rows number ten, not 1,918. The existing quiescent admission planner avoids a settled full desired-registry planning scan. The capture measures about 0.54 ms pose inputs and 0.81 ms motion update, but the animation/effect/pose semantics and source changes prevent an ownership rewrite from those aggregates.

`drive_collision_indexed.gd:358-360` iterates `creature_ids` in `sync_motion`, then its per-creature path returns before spatial upsert while still within the padded index center. It does not scan 1,908 static collision entries per frame. The saved last 240-frame profile measured `drive_publish_motion` about 0.03 ms. The static model groups and 225 terrain tiles are separate movement-query state. `scene_query_index.gd` has no frame process; it enumerates indexed entries on an explicit scene query. Its 1,784 static roots are weak picking/query references, not a second render tree.

`native_scene_visibility.gd:322-355` builds/sorts IDs only from `_active` fading records in `advance`, not all registered static objects. The tile bucket copy/sort occurs on a received tile event. `area_stream.gd:_profile_process` returns after its completed definition, and the saved settled `callback_terrain`, `callback_references`, and `callback_walkmesh` rounded to 0.00 ms. `resource_pool.gd` has no recurring frame traversal in this path; its deep copies and template work occur during request/publication. Retained template, server snapshot, query, and Godot render states have different owners and lifetimes.

The saved render-thread profile counted about 306 instance transform calls per frame; about 59 were equal and 244 changed world bounds, leading to about 251 queued dirty instances and 0.35 ms pair repair. Equal transforms were already detected; removing the real changes would require source-specific appearance and attachment proof. The accepted particle owner alone averaged about 3.26 ms per frame in this capture and is separately owned by NWN-64. The earlier optimistic combat-pivot skip saved only ~0.04 ms per 128 synthetic actors but failed external-edit parity; the stamped safe version regressed. The empty stream copy saved ~0.4 µs/callback and was rejected.

## Decision

No substantial duplicate full-world per-frame read/copy/update is proven across model, material, collision or visibility ownership. Do not rewrite storage or add caches on retained-memory counts alone. The remaining useful gate is a current-source diagnostic of quiet, controlled movement and streaming with the prepared one-shot Node-class census plus owner-specific transform dirty sources. Keep that diagnostic out of FPS timing. NWN-78 remains In Progress; no code candidate is justified by this bounded audit.
