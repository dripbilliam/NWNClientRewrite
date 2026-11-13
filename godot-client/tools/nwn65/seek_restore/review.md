# NWN-65 stopped-player seek restore: rejected

This private candidate replaced `AnimationPlayer.advance(delta)` with `seek(current_animation_position, true)` only for a stopped player that still had a current clip. The original `systems/model_rigs.gd` was not edited. The source copy is `model_rigs_seek.gd` in this directory; the frozen original source SHA256 was `649c85292110a66883b14e5c4155cb3d31312e5b493d822bc637371b196d716c`.

The synthetic one-shot fixture copied the earlier failed-skip oracle. It passed 42 exact checks covering completed pose and clock, event order, attachment and skin state, restart, external stopped seek, queued replay, and an external animated `Node3D` edit. ABBA medians for 12 scheduled owners were 49/50/50/50 µs (control/candidate/candidate/control), with no improvement.

The sealed original `c_goblina:2002` `pause1` fixture passed 17 checks. With 12 completed players, skins and attachments, ABBA component medians were **294/295/295/294 µs**. The original 29-node model and exact final state digest matched across all legs. Reports: `.cache/nwn65/seek-restore-private-a.json`, `.cache/nwn65/seek-restore-original-preflight-a.json`, `.cache/nwn65/seek-restore-original-abba-a.json`.

The candidate does no less measured work in this original-asset case and is rejected. No accepted engine, production rig source, default, or FPS result changed. Active rig publication remains unresolved.
