# NWN-64 empty controls queue slice

Pre-edit `systems/native_render/particle_stream_group.gd` SHA256 `a94f454c13b1598c8e0c943c19617c5a3f8fa78408653486f0b46e024b5dd1cb`; new SHA256 `9dc67c696580c04f9d810b3fabe68af68446ecf16298a497d1c72d63062ce440`. The only edit guards `pending_controls.values()` and `clear()` when the queue is empty. A nonempty queue takes the identical dispatch iteration and clear in the same place, before frame inputs and native presentation. No particle state, RNG, effect eligibility or clock path changed.

The current-source `tests/native_particle_frame_profile_test.gd` passed 236/236, including native command bytes and order, renderer and scene calls, queue drain, failure modes and profiling spans. The focused private fixture `.cache/nwn64/controls-empty-a/controls_empty_test.gd` passed 4/4 empty/nonempty queue assertions. Its 50,000-iteration A-B-B-A component timings were ordinary 10,538/11,425 µs versus guarded 5,243/5,334 µs, around 0.11 µs saved per empty queue. Private receipts: `.cache/nwn64/controls-empty-a/{frame-profile,controls}.json`. `git diff --check` passed.

This is a small real allocation reduction, not a representative particle update or FPS improvement. The ~3–4 ms native presentation/simulation cost remains. NWN-64 stays In Progress for the larger performance and visual acceptance gates.
