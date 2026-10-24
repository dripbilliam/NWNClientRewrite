# Owned tile matrix walk experiment — 2026-10-22 UTC

The previous goal turn was progress: shared world picking was enabled after
paired native local measurements. This turn profiles the resulting production
build and tests a separate cache. No Arelith connection or original-binary write
occurred. The owned dense server and all probes exited after testing.

## Evidence and implementation

`dense-local-shared-picking-production-v1-transform-summary.json` attributes
2.37/2.49/2.48 seconds of transform/traversal CPU samples per roughly 20-second
steady profile to `prepareRendererLights`. Ordinary model animation accounts
for another 0.58/0.65/0.54 seconds. These are CPU stack samples, not GPU time,
and inclusive times must not be added together.

`RendererMatrixSubtree` is an **off-by-default experiment** for explicitly
managed tile trees. It skips the descendant walk when there are no commits,
hierarchy changes, dirty root matrices, forced parent updates or automatic/
custom descendants. Root reparenting and child additions invalidate world
space. Ordinary world queries retain Three's implementation. Cleanup restores
methods and listeners, releasing every owner and node reference.

The first measured implementation notified owners through `commitLocalMatrix`.
The final disabled prototype instead observes `updateMatrix` only on opted-in
objects, so the normal commit path has no experimental lookup or branch.
Its exact local timing is **not** claimed from the older measured version.
Managed light/emitter identity matrices are prepared only for the opt-in build;
their controllers continue to mutate the existing parent node and light/particle
properties. No simulation, light count, resolution or shadow policy changes.

## Checks and decision

`matrix-subtree-v1.json` and `matrix-subtree-gpu-run-v2.txt` verify the final
prototype: all 32 images, point and directional shadow atlases, local/world
matrix hashes, draw and triangle counts equal ordinary managed rendering.
The fixture skips 1,982 root walks without eliminating required dynamic world
multiplications. Thirty focused final tests pass, including moving/nonuniform/
negative parents, commits, forced updates, queries, reparent/add/remove,
automatic/custom fallbacks, retirement, skinning, picking and shadow budgeting.

The earlier exact native comparison bundle `index-D40rgaKA.js` and its matching
`matrix-subtree-ab-source-v1.map` are retained. The same running native dense
scene had 100 tile owners / 5,800 tracked nodes, a fixed camera, and four
alternating ordinary/cache pairs (3 seconds settling and 9 seconds profiled
sampling per phase). Every candidate phase skipped all unchanged tile walks;
all owners/nodes retired to zero after disconnect. Renderer errors were empty.

Mean world-matrix stage time in each ordinary/cache pair:

| Pair | Ordinary | Cache |
|---|---:|---:|
| 0 | 2.356 ms | 1.853 ms |
| 1 | 2.278 ms | 1.856 ms |
| 2 | 2.312 ms | 1.842 ms |
| 3 | 2.325 ms | 1.797 ms |

Paired FPS changes were +4.05/−1.69/+5.60/+2.53%. The medians of phase FPS
were 29.10/30.28, but sampled frame-work medians were 32.4/33.5 ms and p95
window medians 38.9/38.3 ms. NPCs continued walking, and rolling FPS and sampled
frame work have different sampling windows. This proves eliminated traversal
and a consistently smaller matrix stage, **not a convincing whole-client gain**.
The cache remains disabled; acceptance still requires sustained >=60 FPS and
p95 <=16.7 ms in a representative workload. Those conditions are not met.

The normal build `index-CTP8rA1Q.js` has no comparison hook and passes an isolated
packaged renderer/preload boot with zero joins/fetches/errors. Its live snapshot
asserts disabled with zero owners, nodes, walks and skips. The shared-picking
change remains enabled. `matrix-subtree-normal-source-v1.json/.map` matches the
normal bundle byte-for-byte. No native FPS claim is made for this normal build.

## Next larger target

The current renderer still submits around 2,000 draws in this authored scene.
`buildMesh` constructs materials per instance, and
`CameraKeyholePresentation.bind` clones each static tile mesh's material for its
per-draw can-dissolve uniform. A naive shared-material pool would therefore be
cloned again, or would break per-object dissolve state if sharing were forced.
`TargetPreviewShader` also computes world positions without instance transforms.

Persistent static-tile instancing needs a correct per-instance keyhole flag,
instance-aware target preview, material/controller eligibility, picking/source
ownership, shadow handling and draw-order evidence. The prior ordered main
batcher is still disabled: short runs and repeated descriptor/palette work
outweighed its saved draws. Do not enable it or reduce fidelity to manufacture
a better FPS number. Native per-object light lists and static lighting remain
another unresolved difference from the original renderer.
