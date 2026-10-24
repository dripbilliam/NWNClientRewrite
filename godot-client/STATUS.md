# Native import milestone — 2026-10-22

The native desktop project runs in this folder. The existing Electron client
and normal `dist` bundle are preserved. No Arelith connection was made.

Godot 4.7.2 official, build `ed1daf0bf001b61586d9930840f2f1394092c079`,
Forward+ / Vulkan 1.4.351 on RTX 5070 Ti. The official Windows archive was
SHA-256 verified and both extracted executables have valid Windows signatures.
Headless initialization and no-scene startup passed. Five authored bridge
checks passed, including the trusted file-URL regression and empty-world guard.

The complete offline source world had 898 eligible objects, 1,077 models and
1,357 emitters (700 pre-existing unsupported emitters). The frozen bridge
exported 4,145 source-visible mesh nodes, including 115 active particle mesh
nodes, 167,633 triangles and 102 real light nodes. This is not a conversion of
the full animation/effect simulation. Export identity:

`06b655659361c8e9a6f0ce13c9db20b8b8f9a32cbf724a789717c87b534347e2`

The 307,317,172-byte GLB and source manifest are outside this workspace at the
external temporary path recorded in `reports/import-v1.json`. No proprietary
asset payload is copied into the project. A first bridge attempt produced an
empty scene because its trusted application URL was absent; that failure is
retained and was not used for a performance result. The corrected bridge checks
canonical membership before transfer and verifies hash/mesh count on import.

The native run imported all 4,145 nodes, with matching 898-object source
inventory and 1424×921 drawing buffer. It exited successfully after 600 measured
frames following at least 16 seconds / 120 frames of warm-up:

| Observation | Result |
|---|---:|
| Runtime glTF loading (excludes later shader warm-up) | 6,207.45 ms |
| Mean frame interval, wall-clock observations | 22.434 ms (~44.6 FPS) |
| p95 interval | 35.607 ms |
| Worst interval | 48.305 ms |
| Last engine draw calls / primitives | 3,192 / 124,319 |

Artifacts: `reports/import-v1.json` and `reports/import-v1.png`. The native
process guard refused other game instances; Electron had exited before this
run. These are one-run frozen-scene diagnostics, not repeated matched gameplay
benchmarks or GPU-only timestamps. The screenshot was inspected and shows
substantial lighting differences and incorrect additive particle quads.

**Acceptance remains false.** The user now permits visual differences provided
models and textures remain the same. Stock engine lighting is therefore an
allowed presentation choice, subject to review. Model/texture integrity, mip
handling, frozen skeletal/particle poses, broken additive blending and absent
gameplay/UI/network integration still prevent migration acceptance.
The 60 FPS / p95 <=16.7 ms target is not met even by this
initial prototype. The [migration plan](MIGRATION.md) keeps those requirements
explicit. The next work belongs in this native project, not more small
Three/Babylon experiments.
