# Native live server effects: partial integration

The isolated v23 client delivers decoded server duration and instant visual
events to a per-world Godot effect list. Native selection, phase timing,
attachment, private geometry and worker particle lifetimes operate together.
This is a functional milestone, not complete effect or renderer parity.

## Delivery and ownership

`tools/visual-delivery.mjs` reserves native list positions before asynchronous
definition preparation. It reuses original record/instant routing and the
definition loader. Preparation is bounded to two jobs. Session, world, area
generation and actor identity reject stale results. Native removal scans the
physical head, including pending reservations; cancellation feedback stops late
publication. The isolated build disables only the hidden Three object-effect
presentation, preserving original asset providers and production source files.

`systems/visual_world.gd` owns selection, per-world cached resources, runtimes
and private models. `visual_runtime.gd` connects the previously tested phase
clock to placement and ordinary named clip playback. Manual part P/Q and scale
gates survive animation updates while descendants still animate. Flags 3
initially copy anchor orientation, then retain it during subsequent updates.

Private emitters reuse the particle worker pool. Their IDs/bindings cannot
collide with canonical gameplay objects. Canonical/private patches serialize
across worker acknowledgments. New emitters wait for their first native pose
before simulation or random draws. Removal releases surfaces, subscriptions
and worker rows; late acknowledgments cannot resurrect a removed model.
Same-world exports share promises to retain stable emitter metadata.

## Actual local evidence

`reports/native-visual-effects-local-v2.json` passed against the installed
owned server at 127.0.0.1:5121 using authored module `GodotVisuals`:

- All 16 examine/dialogue/reply/end/abort/chat/color/token/portrait checks pass.
- All 11 live effect checks pass. Ordinary chat commands run actual server
  scripts applying duration Darkness (visual 1, six seconds) and instant
  Healing (visual 69). Actual decoded add/remove/instant messages are recorded.
- Original geometry/private particle vertices reach Vulkan. Active/hidden
  captures differ by 605,531 pixels; this proves drawing, not fidelity or FPS.
  Maximum observed private particle count is six vertices. Actual creature-root
  attachment and persistent manual gates are checked.
- Server expiry drives cessation and private-model/particle cleanup. The instant
  retires without a fabricated remove. Existing buffs remain.
- The native engine log is clean and renderer errors are empty. Shutdown has
  zero pending effect jobs and zero remaining particle worker threads.

The first local report is retained as failed evidence: two cleanup assertions
incorrectly required the entire private list to be empty despite existing
character buffs. Corrected assertions track each test effect's own model and
emitter identities. Both tested effects were already retiring in that run.

Additional retained checks:

- `reports/visual-selection-native-v3.json`: 3,339 assertions over 1,221 retained
  original selection/competing-detach observations, not fresh binary profiling.
- `reports/visual-live-node-v3.log`: 34 Node cases including stale completion,
  cancellation, shared cache, private IDs, first-pose simulation and concurrent
  canonical/private mutations.
- `reports/visual-model-native-vulkan-v3.json`: 78 private-model checks covering
  manual gates, initial flags-3 attachment, animated descendants, skin/reference
  arithmetic and drawing. Maximum skin error is 0.000015259.
- `reports/visual-live-rigs-v1.json`: all 65 existing creature-rig GPU checks
  pass. Both native regressions have clean dedicated engine logs.

Fixture metadata: `reports/visual-server-fixture-v1.json`; module SHA256
`e5eb64619d67c1bf51397fb67c27a573fc28b5e8e0b67e5581a77b9e89dcced0`.
Original resource payloads remain in external temporary bundles. Screenshots
are render captures. Repeat with `join-local.ps1 -VisualSmoke -Report
<unused-name>.json` against that owned module. Preserve other games/editor.

## Explicit remaining work

Subsequent [native effect animation](NATIVE-EFFECT-ANIMATION.md) connects the
original run/controller owners for binary private models, including mesh alpha,
self-illumination and emitter fields. Decoded-only models retain the temporary
single-clip fallback. Complete specialized controller/light behavior remains. Type-7
procedural reattachment is diagnosed and hidden. Full program types, view
gates, suppression, source/target/point dummies, beam retargeting, positional
audio and projectile stages remain. Root orientation needs native scale/sign
edge-case oracles.

Existing bitmap/wind particle-provider limitations are reported; zero buffer
failures does not imply support for every emitter. Active/pending-effect
transitions and reconnect need actual integration checks. Full migration and
sustained complete moving-world >=60 FPS remain unaccepted. No Arelith
connection was made. The editor was preserved; these are functional tests,
not clean performance benchmarks.
