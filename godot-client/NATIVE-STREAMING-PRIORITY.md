# Playable while background objects stream

The native world now prepares terrain/walkmesh and the complete controlled actor
before queuing other creatures, ground items and static objects. Original
area-ready acknowledgment still follows terrain readiness to release player
replication; it does not wait for the player and deadlock initial admission.
Player models, body parts and equipment remain a complete hierarchy at publication.

Player input readiness waits for that actor's own physical referenced models,
including nested references. Distant scenery's pending references no longer gate
movement. Background actors/items and static objects are ordered by distance from
the player, with deterministic ID ties, and prepared in batches of at most 32 and
64 objects respectively. At most two background owners leave room for a changed
controlled appearance. Existing per-frame publication budgets, unchanged-asset
reuse, stale appearance-key rejection and native worker cleanup remain active.
No received records or distant scenery are dropped. This changes preparation
priority, not authority or the finished scene's contents.

## Evidence

- `native-streaming-priority-v1`: 46 checks on the actual planner and reference
  readiness, including source ordering, nearest-first bounded batches, in-flight
  exclusion, terrain gate, controlled equipment changes, nested references,
  retired requests, eventual admission of all 30 background objects and error
  retry suppression. Authored delayed work, not a real-server/GPU benchmark.
- `native-session-streaming-priority-v1`: default launcher, owned localhost
  campaign. Player ready at 1455.517 ms with 18 background entities pending.
  Final scene: 20 entities and nine tiles. Server and native movement agree at
  approximately 1.500033 m. Historical host pin after telemetry addition.
- `native-session-streaming-priority-v2`: final warm localhost launch. Player
  ready at 1437.994 ms; first observation has one rendered entity, 19 desired,
  two background batches. During incomplete streaming, native movement is
  0.380541 m and independently received server movement is 0.150333 m, with
  18/20 entities and two batches. Different sample times account for the
  intermediate distances; final distances agree within 0.001 m. All 20 entities
  finish, protocol finish is acknowledged and zero workers remain.
- `native-streaming-reference-gpu-v1`: 147 original/authored reference graph,
  private attachment, moving chain, target-loss and cleanup checks. Screenshot
  inspected. This is a scoped local asset fixture, not complete VFX acceptance.

All named checks use normal-heap CDB with four native exception traps, unchanged
runtime sources and no trapped exception or engine/lifetime error. The actual
launcher retains its protocol-only JS host, with no loaded JS render/particle
dependency. No public connection occurred. `tools/check-native-streaming-priority.mjs`
checks current source pins and these specific claims; success does not accept the
full migration or performance goal.

These are warm-cache Prelude measurements from native world opening, not
end-to-end connection times, cold-load results or dense-room FPS acceptance.
Background publication can still hitch on an individual expensive model; terrain
currently waits for the entire area's terrain/walkmesh. Full moving captured
replay, repeated streaming transitions/reconnects, complete effects and sustained
60 FPS remain open. The historical native shutdown fault is not declared resolved.
