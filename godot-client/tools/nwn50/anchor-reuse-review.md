# NWN-50 placeable-light anchor reuse

Production file: `systems/native_render/placeable_lights.gd`.

Frozen pre-edit SHA-256: `4bbb3c3e9531bccf8d46b1d5849ac5b3edee4a287eabab7482def3ed183a8382` at `.cache/nwn50/anchor-a/control.gd`. Candidate SHA-256: `8986e883a984785967c44f0c487d977155391ebb8fe9282c55c6ca02047d2583`.

On a dirty pass, each dynamic light previously called `anchor(id)` for admission, then called it again in `apply`. The second lookup repeats a world instance lookup, `node_for` or root-part traversal, and validity checks. The candidate forwards the admission result to `apply` only when the plan is unchanged. A changed plan still resolves after `set_part_local_pose`, preserving possible side effects and the original attachment order. Direct `apply` calls retain their own lookup. Static lights require none. This removes one anchor traversal per unchanged dynamic light per dirty pass; it does not claim a frame-time or FPS improvement.

`tools/nwn50/anchor-reuse-test.gd` with `anchor-probe-owner.gd` passed 5/5 under the private Godot 4.7.2 headless executable. It covers unchanged and changed dynamic plans (including an anchor swap during pose publication), direct apply, unavailable anchor, and static detachment/pose. `git diff --check -- systems/native_render/placeable_lights.gd` passed. Godot emitted only the existing user-log and Windows certificate environment errors during this focused run.

The existing `tests/native_perf140_particle_light_plans_test.gd` ran 19 checks with one failure at its signed-zero plan-cache assertion. That assertion exercises `plans()` and a separate private candidate, while this patch changes only `apply()` and `_process()`. It is not counted as a pass and needs separate baseline triage if relevant to that candidate.

Remaining acceptance: original installed-light lifecycle and visual verification were not rerun. The duplicate occurs only on dirty passes, so this is a small work reduction in NWN-50 rather than a recurring render-thread optimization.
