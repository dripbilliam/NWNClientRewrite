# Scene snapshot measurement and animated picking repair

2026-10-20. Live testing remains restricted to the owned local server. This
investigation was offline and did not restart the open client or join a server.

The automatic scene diagnostics call `Box3.setFromObject` every 200 ms. Its
normal Three.js path caches each geometry's bounding box. Our skin callback
updated positions, normals and the bounding sphere, but left that cached box
at the old pose. Three.js `Mesh.raycast` rejects a ray outside a non-null box
before testing triangles. Thus requesting diagnostics could cause missed picks
on deformed geometry. This is a renderer integration defect, not a new claim
about the original game's movement or collision rules.

`test/model-skin-bounds.test.js` reproduces an actual miss: cache the initial
box, move a bone through the existing skin solver, and raycast the moved
triangle. The factored, unchanged callback fails with zero hits instead of
one (`creation-performance-skin-bounds-before-v2.txt`). `updateSkinnedMesh`
now invalidates the optional box after deformation. Raycasting uses the fresh
sphere; a subsequent box consumer computes the current bounds. The regression
also checks a second displacement and correct new extents. The initial v1
test log only records a missing export during test development, not a behavior
reproduction. 33 focused model/movement checks and the production build pass.

The CPU fixture assembles an installed Prelude character through the actual
production asset/hierarchy/animation callbacks (12 models, 116 nodes, 11
meshes). It copies that posed hierarchy with independent geometry into
synthetic crowds of 1/16/64/128 characters. It times the production scene
snapshot and JSON serialization separately, without rendering. Each case has
35 samples; the first five are excluded from settled statistics. A second
mode invalidates *every* copied mesh box before each sample, so the timed work
includes fresh box calculation. This mode does not time actual animation.

| Characters | Cached median / p95 | Invalidated median / p95 |
|---|---|---|
| 1 | 0.1 / 0.2 ms | 0.2 / 0.2 ms |
| 16 | 0.4 / 0.6 ms | 1.0 / 1.2 ms |
| 64 | 1.1 / 1.1 ms | 1.8 / 2.2 ms |
| 128 | 1.6 / 1.8 ms | 3.7 / 4.9 ms |

This bounded result does not explain the reported roughly 100 ms frames.
No diagnostics cadence change is justified by it. It is not live FPS or a
draw/GPU/animated-crowd/fullscreen acceptance result. The known missing tile
flame attachment diagnostic remains recorded. The first v1 experiment used
fixed poses and did not actively account for browser HTTP; v2 rejects Node
fetch and cancels non-loopback browser HTTP (one debug Google Fonts request).
No proprietary asset was written to the workspace.

`scripts/verify-network-snapshot.mjs` checks current source hashes, both modes,
network accounting, the failure/pass evidence and the current packaged menu
and resource IPC check. It writes `creation-performance-network-snapshot-proof-v1.json`.
The earlier exact native movement replay and local captures remain evidence
for their recorded builds, not a fresh live test of this bounds-only build.
Short contact pauses, combined movement/turning, nonzero position correction,
and controlled local message latency remain useful next movement checks.
