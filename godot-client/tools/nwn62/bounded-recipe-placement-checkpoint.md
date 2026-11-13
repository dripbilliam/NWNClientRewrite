# NWN-62 bounded recipe placement checkpoint — 2026-11-12

The staged recipe path already bounds node creation. It still called `ModelTemplate._placement_from_root()` once after a clone when the model had at most 64 physical parts, even if the actual detached tree had more than 96 nodes. That call performs two recursive engine child searches, a part sort, pick filtering, and possible reference graph setup inside one publication callback.

An explicit `--model-placement=bounded-large-recipe` opt-in now routes those recipe graphs through the existing `PlacementJob`. It also captures the placement index during incremental clone creation. The first detached root uses the same job without an index. The ordinary default, PackedScene cases, and existing >64-part route retain their selection. `NativeModelRecipe.node_count()` exposes the existing captured row count without allocating a diagnostic snapshot each step. No accepted executable or default option was changed.

## Local evidence

- Frozen pre-edit `model_template.gd` SHA256 `69599C4460DEE89260916A009DBAA9DBF8528B4F6157A6FD5AD5E09BF45F85D2` at `.cache/nwn62/bounded-placement-a/before/model_template.gd`.
- Current `model_template.gd` SHA256 `D41DDA3C500D04DE03F2318421EA5D7C6F045DB46C9392C57799B85D46B77BC8`; `native_model_recipe.gd` SHA256 `6742B80C4CDF12F6A1615CACBF6AE6AB683CAE04F52422AD77E61036BE0B4D7C`.
- `tools/nwn62/bounded-recipe-placement-test.gd` ran headless with the opt-in and passed 15/15 checks. Its 64-part, 128-node fixture includes the original emitter and reference helpers. It compared frozen and candidate first roots and clones for complete node rows, part/mesh/pick ordering, bounds, model name, limitations, and reference graph contents. The opt-in returned at most one requested construction unit per step; cancellation freed the pending first root and a fresh clone subsequently succeeded. Report: `.cache/nwn62/bounded-placement-a/report.json` SHA256 `A88241393EAF8B6B8265286CE5A97F0ED983C8325EC7A373E261BC746CAB5DCF`.
- With a deliberately strict one-unit cap, frozen first placement completed in one call; opt-in first placement took 255 calls. Frozen clone took 128 calls and still finished placement in its final call; opt-in clone took 256 calls. These are yield counts, **not** frame-time or loading improvements.
- Default small PackedScene behavior passed 18/18 headless checks. Existing indexed placement parity/cancellation passed 20/20. `git diff --check` passed on the owned source files. The headless runs printed the existing unavailable user log/root certificate diagnostics but completed with exit code 0 and passing reports.

## Remaining acceptance

The opt-in reduces the scope of a single placement callback for a demonstrated graph; it does not yet establish that the saved 75.073 ms Arelith callback was this operation. The staged template's individual `PackedScene.pack`, source install/material work, and other world publication operations remain unbounded. Once an exclusive PC timing lease is available, measure current-source callback tails and full known-scenery completion with this flag on and off before considering a default change. Retain NWN-62 In Progress and the previous packed/cooperative loading comparison as separate evidence.
