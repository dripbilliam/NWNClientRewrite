# NWN-72 short duplicate audit (2026-11-13)

Current `systems/network_motion.gd` SHA256: `bc6d3c8d26cd041a5f9977ac8f3357cd72b3102b7e2b9afa7060c0bd18176499`.

`update` tests `path_animation(int(state.animation))` in its active-path branch and again before choosing its facing target. This is **not** an exact duplicate: `step_path` can assign `state.animation = 3` at the terminal path point, and it calls an external `support_query` or `height_query` between the tests. A cached predicate would conceal a reentrant state edit. No source change was made.

The same loop reads `facingTarget` before calling `update_facing_target`, which reads the key again. That second lookup affects only targeted rows; the issue has no current targeted-row count or component cost proving a meaningful gain. The larger remaining motion/pose opportunity requires active/unchanged entity counts and dirty/temporal wake semantics, outside the agreed short slice. Current ticket remains In Progress.
