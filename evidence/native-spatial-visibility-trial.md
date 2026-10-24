# Conservative hierarchical visibility trial

2026-10-22. Outcome: **not promoted; slightly slower than its control**.
The native rendering-parity goal remains active and incomplete.

## Implemented candidate

`src/renderer_spatial_visibility.js` builds an independent bounds hierarchy,
reduces active plane tests down the tree and refits changed bounds. It follows
the conservative AABB/plane and hierarchical-plane-reduction ideas established
in the [native method map](native-rendering-parity-goal.md). It does not claim
the original BSP layout, tile fading, LOD, occlusion or complete native parity.

The private `spatial-draws` mode adds it to `cooperative-draws`. Ordinary Three
frustum tests, ordering, lights, materials, shadows and resource owners remain.
Unknown/custom shader geometry, instancing, GPU skins, displacement, morphs and
disabled culling use the ordinary path. No light/shadow cap, resolution or
visible-content reduction is used. The normal entry point and installed build
are unchanged.

Bounds reuse observes geometry/channel identity, position version/count/array
and world-matrix changes; membership replacement prunes detached owners. Camera
planes are queried every frame, including rotation without object motion.
Changing geometry updates local bounds; moving an object reuses its local
bounds and refits world bounds and ancestors. Context restoration and disposal
release the index. This initial version still checks source records each frame;
it is not yet a fully event-driven native ownership implementation.

CPU checks: **37 pass**, covering 12 visibility/integration cases and 25 replay
fidelity/measurement cases. Hierarchy tests compare conservative admission to an
independent transformed-vertex oracle and include multi-level refits, touching
planes, negative scale, mutation, fallback changes, reset and camera changes.
Timing validation requires actual indexed bounds and plane queries at both
endpoints; a selected mode label alone cannot pass activation.

## Complete captured-room comparison

Private build:
`backups/animations/performance-queue/native-spatial-v2/diagnostic-build`.
Report: `runtime-logs/performance-queue/native-spatial-v2/room-v2.json`.
Independent timing validation:
`runtime-logs/performance-queue/native-spatial-v2/timing-summary-v2.json`.
The earlier v1 build was prepared before the parity whitelist was complete and
was not run; v2 is the measured build.

The same run used 1424×921, the same frozen camera/content/settings, a 16-second
warmup and 20-second observation per phase. All phases retained 898 objects,
1,077 models and 1,357 emitters, including the unchanged 700 pre-existing
unsupported emitters. No analysis/build jobs ran during the comparison. All
server/resource delivery came from the private capture; no Arelith connection.

| Phase | Mean frame | FPS | p95 frame |
|---|---:|---:|---:|
| Baseline first | 56.187 ms | 17.798 | 62.7 ms |
| Cooperative first | 46.141 ms | 21.673 | 52.7 ms |
| Spatial first | 47.107 ms | 21.228 | 54.1 ms |
| Spatial repeat | 47.179 ms | 21.196 | 54.5 ms |
| Cooperative repeat | 45.811 ms | 21.829 | 53.4 ms |
| Baseline repeat | 55.644 ms | 17.971 | 62.8 ms |

The timing validator accepts the repeated comparison and baseline drift checks;
the target is false. Spatial visibility is approximately 2.5% slower than its
cooperative control. It is not an improvement over that control merely because
it beats the older baseline.

Typical spatial counters: 4,839 source members, 4,529 indexed, 310 fallbacks,
140 changed bounds, 4,389 reused bounds, 1,851 plane tests, 1,461 visited nodes,
60 rejected nodes, 2,949 admitted indexed candidates and no steady-state rebuild.
Total main/shadow calls fall only from about 2,796 to 2,750. The removed work is
too small to repay source checking/tree overhead in this room.

The same-task **independent non-MSAA** target comparison has exactly zero
different color channels and zero different shadow-map channels for both
cooperative and spatial candidates, with a stable repeated reference. The
default MSAA framebuffer comparison fails strict equality: the repeated
baseline itself differs in four pixels by one byte; spatial differs in 50
pixels by one byte. Keep that failure; do not loosen the gate or present this
as full visual/native/gameplay acceptance.

The original replay outer gate also stays failed because its last recorded
frame has the known partial object/model/emitter counts. The completed replay
matches the independent canonical inventory instead. Its top-level exit code
is therefore 1; it is not an accepted end-to-end rendering-parity result.

Cached draw GPU query intervals range roughly 33.5–37.7 ms. They include CPU
supply/driver effects and exclude simulation; they are not isolated GPU-busy
times or full-game FPS. They do support investigating native shader/light work
next, rather than treating this small culling reduction as the main fix.

## Next native investigation

The read-only hash-gated `scripts/inspect-native-render-flags.py` found a direct
write to `g_bFullDynamicLighting` (`0x14140ac58`) at instruction `0x1406bd270`,
inside the PE unwind range beginning `0x1406bd260`. It loads a byte from the
second argument, stores the flag and passes it to calls at `0x1406bd276` and
`0x1406bd284`, targeting `0x1400bf150`. This is a writer candidate, not a named
configuration callback or proof that a particular shader-quality preset sets
the flag. Map its registration/callers and the destination API next.

Source: `runtime-logs/native-render-parity/render-flag-references.json`.
Target: NWN:EE 89.8193.37-17, SHA-256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The scan covers direct RIP-relative accesses decoded inside PE unwind ranges;
leaf functions without unwind records and indirect aliases are explicitly
outside coverage. Finding one write here does not prove it is the only writer.
