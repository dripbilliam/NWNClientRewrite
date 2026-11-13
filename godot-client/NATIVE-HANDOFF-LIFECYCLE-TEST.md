# Native destination lifecycle boundaries

`tests/native_handoff_lifecycle_test.gd` extends the actual SessionWorld
SceneTree and suppresses only normal `_initialize` startup. It never creates a
second tree, connects transport, reads an installed/profile context or starts a
visible renderer. It observes fatal-report and outbound-producer calls without
turning them into transport, acknowledgements or altered admission rules.

Host must reuse these existing boundaries:

1. Advance destination connection through lobby or session-reset **before** its
   setup. Higher-connection setup alone is refused.
2. Reset closes/queues old Gameplay/NUI, retires the old world, joins/cancels the
   old catalog owner, clears pending raw assembler/base and preserves raw serial.
3. Setup captures its loader identity across the asynchronous mount. A completed
   old loader cannot configure destination UI or emit catalog-ready after reset.
4. Await destination's existing scoped catalog-ready before sending its first
   raw full snapshot. Reset Host rawPending/setupSession/delta planner; preserve
   its globally increasing serial. No new retirement acknowledgement is needed.
5. Reject retired raw/UI/speech/NUI and native ACKs by connection ownership. The
   Godot test observes no ACK producer from old raw tails; Host ACK admission is
   its separate protocol responsibility.

The26 authored checks use actual idle World/WorldRetirement and Gameplay/NUI
owners, with NUI presentation polling disabled. Actual SessionCatalog workers
read only a new owned empty recorded-catalog manifest. Both origin and
destination setup are deliberately retired before full Gameplay configuration;
the destination poll is disabled to hold its real suspended setup while an old
completion is emitted. No fake successful resource admission is asserted.

The first-delta negatives include origin base reuse and matching reset
sentinels (`accepted_raw_serial=-1`, epoch−1). A sentinel is not an accepted
snapshot. The existing source equality guard may expose that latter gap; Root
owns any shared correction after rejected evidence is retained.

The runner copies the current static dependency closure and needed feedback /
extension descriptors into a new private project, with current engine, six
native-output and main project/extension-list guards. A new65s headless run
requires Root's source/CPU lane grant. No sockets, public server, profile/key,
native build, main config write, GPU or user-process control is used.

```powershell
node godot-client/tools/test-native-handoff-lifecycle.mjs native-handoff-lifecycle-v1
```

These are controlled lifecycle checks, not a captured cross-server handoff or
full destination scene acceptance. The existing catalog-ready/raw ACK and
retirement owners remain the integration contract.
