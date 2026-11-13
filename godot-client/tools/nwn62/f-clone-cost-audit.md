# NWN-62 F clone and loading cost audit

This is read-only analysis of the accepted model code, private F overlay and saved accepted-source/Core E original-scene ABBA reports. No production source, client or FPS run was changed here.

## What F adds

F routes five original small models from `PackedScene.pack`/`instantiate` to the recipe. All four legs reused their first prepared root. Both F legs built 20 recipe templates versus 15 in controls and made 427 recipe clones versus 401. Thus the selected five graphs account for **26 additional recipe clones** in this scene. The control/candidate total-template counts differ by one or two across runs, so packed-clone count is not a precise subtraction for the converted set.

For each of those clones, `NativeModelRecipe.Creation.step()` visits every captured node and invokes a GDScript constructor or a packed light-leaf instantiate, reflected field setters, metadata cloning, light configuration, surface override setters, `add_child` and owner assignment. The accepted packed route uses one `PackedScene.instantiate()` for the graph. F's small recipe clones then call `ModelTemplate._placement_from_root()`, as packed clones do; that routine performs two recursive `find_children` searches, part sorting, pick filtering and possible reference-graph setup. The recipe's optional placement index is only enabled for large graphs or the separate bounded-placement opt-in, so it does not remove these traversals for the five F graphs. These are exact source-path differences; no source timing is inferred from them.

| Saved metric | Candidate 1 / Control 1 | Candidate 2 / Control 2 |
| --- | ---: | ---: |
| Recipe templates | 20 / 15 | 20 / 15 |
| Recipe clones | 427 / 401 | 427 / 401 |
| Terrain clone CPU, ms | 44.394 / 39.570 | 41.197 / 38.261 |
| Terrain template CPU, ms | 331.172 / 599.175 | 306.317 / 1,079.727 |
| Largest small-pack step, ms | 18.065 / 94.150 | 37.841 / 646.519 |
| Largest terrain callback, ms | 19.346 / 73.793 | 36.638 / 649.259 |
| First playable, candidate minus control, ms | +174.729 | −278.674 |
| Known-base complete, candidate minus control, ms | +1,047.209 | +77.739 |
| Steady mean frame, candidate minus control, ms | +0.050 | +0.164 |

F removes the observed 646 ms original `ttu01_w07_01` pack/terrain tail while adding about 3–5 ms **aggregate measured terrain clone CPU** in each pair. The added clone work is real, but these measurements cannot explain a 78–1,047 ms known-base completion difference by clone CPU alone. Candidate 1's terrain worker time was 2,302.779 ms versus 1,820.021 ms in its control (+482.758 ms), while candidate 2's was 1,659.415 versus 1,701.908 ms (−42.493 ms). This variation and other concurrent entry work prevent assigning the full loading delay to F. A 0.48–0.56 s average loading regression is an observation, not a diagnosed clone cost. No repeatable steady FPS improvement is shown.

## Concrete lower-work candidate

Test a **light-leaf hybrid** privately on the same five source-hash-guarded graphs:

1. At detached template capture, validate the same two auto-named light leaves and reject active bindings or unknown child/reference state. Save each leaf as the already-proven tiny PackedScene, with its exact parent and sibling index.
2. Temporarily remove those leaves, pack the remaining graph once, and restore the original first root. If the remaining pack still has a severe tail, reject this candidate immediately.
3. For later clones, instantiate the packed non-light graph through Godot's native engine path, then instantiate/insert only the two light leaves at their original positions and restore ownership before scene admission. This replaces per-clone GDScript construction and reflected setters for every non-light node with one native instantiate and two bounded leaf insertions.
4. Compare full first/clone rows, names, transforms, materials, metadata, child order, lights, references, cancellation and reset against the original packed oracle. Measure total template+clone CPU and known-base completion in an exclusive matched run before deciding on promotion.

The hybrid is a **candidate**, not a proven fix: the existing data do not prove that light serialization caused the long `PackedScene.pack` calls. Its first gate is whether packing the light-stripped original graph stays below the tail. A simpler placement-index shortcut would remove two clone traversals, but F's measured extra terrain clone CPU is only about 3–5 ms total; it cannot plausibly recover the observed full-base latency alone. Keep F and NWN-62 unpromoted/In Progress.

Evidence: `reports/nwn62-small-recipe-f-b-{candidate-1,control-1,control-2,candidate-2}.json` and corresponding `.performance.jsonl`; private F source receipt `.cache/nwn62/small-recipe-f/source-receipt.json`; accepted `systems/native_render/{model_template,native_model_recipe}.gd`; prior E comparison `tools/nwn62/small-recipe-e-matrix-checkpoint.md`.

## Private hybrid feasibility, no production edit

The proposed hybrid now exists at `.cache/nwn62/small-recipe-h/systems/native_render/model_template.gd` (SHA-256 `a817d65b0ed0a0bf9d88402cafd9b00a6f1d30c986ae04b473bb54a8df9dc883`). It uses the same five name/source-hash guards as F. During detached template preparation it validates exactly two auto-named, inactive light leaves, packs each as a tiny scene, removes them, packs the remaining graph once and restores the original first root. Subsequent clones instantiate the non-light scene and insert those two leaves at their recorded parent paths and sibling indexes before placement. If the leaf structure or stripped pack fails, it restores the original graph and falls back to F's recipe capture. The accepted template and recipe hashes remained `d41dda3c…` and `6742b80c…`.

The corrected exact-original-model headless fixture passed **90/90** checks for five hybrid targets and five packed comparators. First and subsequent clone graph rows, names, order, transforms, metadata, light/material descriptors and paths matched the full PackedScene oracle. No script errors or warnings remained after clearing detached leaf ownership before reattachment. The first fixture attempt used a property absent from the control class; the second exposed the owner warning; the corrected third report is `.cache/nwn62/small-recipe-h/correctness-c/report.json` SHA-256 `7433e4f33338371a92d7b9d842d60ea39a2bdd98fe26aa11fc2c4f2aaafff344`.

| Original target | Full pack, µs | Stripped skeleton pack, µs | Two tiny leaves pack, µs |
| --- | ---: | ---: | ---: |
| `ttu01_a02_03` | 508 | 259 | 92 |
| `ttu01_h17_01` | 1,133 | 539 | 97 |
| `ttu01_v06_01` | 246 | 134 | 76 |
| `ttu01_w07_01` | 531 | 390 | 87 |
| `ttu01_l07_02` | 1,222 | 1,306 | 113 |

The light-stripped pack stayed at or below **1.306 ms** in this headless fixture, but the full pack was also short in the same environment. In particular, `ttu01_l07_02` packed slightly slower after stripping, so the fixture does **not** establish that lights caused the hundreds-of-milliseconds graphical stalls. The hybrid is a correct local prototype with a plausible clone-work reduction; it is not ready for promotion or a loading/FPS claim. Its next gate is a source-pinned original-scene comparison under an exclusive PC lease, including maximum pack tail, clone CPU, full known-base completion and visual parity. Preserve F and the accepted client as rollback paths.
