# Rejected compact leaf Part experiment

Historical default-policy decision, 2026-10-27. The user subsequently requested
keeping this as an Options toggle. It is restored as **Compact scenery
(experimental)**, default off, applying at the next area boundary. See
`NATIVE-COMPACT-SCENERY.md`. The measurements and initial rejection below remain
valid historical evidence; they are not proof the option is harmful or useless.
No public connection was made.

The candidate let a renderable leaf MeshInstance3D also represent its private
physical Part. Parent Parts, hidden collision geometry, emitters, references,
lights, skins, animated meshes and dangly features retained the existing path.
It did not merge geometry, reduce objects, replace textures, or share mutable
instance state. Template identity isolated the two policies. It preserved the
original physical part count while removing redundant render-leaf wrappers.

The read-only original PartTriMesh constructor/instance dossiers already saved
for NWN SHA256 3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a
support a private renderable physical Part referencing shared model state.
This motivated the candidate; they do not establish Godot node cost or native
batching policy. New native code was not patched, annotated or executed.

## Correctness evidence

`native-loading-compact-template-v1`: existing16-check template/cache ownership
regression passes. `native-loading-compact-original-exact-v2`:70 checks compare
the pinned authored pre-change implementation against three actual original
models from the sealed capture. GPU pixel buffers are byte-exact. Physical
metadata/rest transforms, GPU streams/material state, original polygon hits,
source immutability, packed private state and teardown agree. Direct subtree
counts fall65→36,105→56 and18→14, with all original Parts/meshes retained.
The first exactness fixture failed on a missing GDScript type annotation; v2
corrected the fixture without weakening assertions. Failed evidence is retained.

## Same-source complete-area comparison

All four `native-loading-compact-area{3,4}-{separate,compact}-v1` runs complete
all441/630 expected entities, with unchanged source/input identity and clean
engine/lifetime gates. Area4 runs separate then compact; area3 reverses order.
No other game client was running during these serial observations.

| Area | Policy | Final scene nodes | Last sampled FPS | Last rolling mean wall ms | Last rolling p95 ms | Player ready ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 4 | Separate | 21933 | 162 | 6.142 | 7.387 | 3550.216 |
| 4 | Compact | 16852 | 156 | 6.357 | 7.918 | 3486.681 |
| 3 | Compact | 13248 | 175 | 5.496 | 7.390 | 3408.457 |
| 3 | Separate | 17249 | 186 | 5.297 | 6.723 | 3704.410 |

These are short profiled observations with differing FPS/rolling windows, not
statistical measurements or full original-client parity. Readiness changes are
inconsistent in size; the private actor path is unchanged. Node reduction is
about23%, but both last steady frame samples are slightly worse. Area4 observed
clone peaks fall only1.626→1.606 ms, while attachment peaks rise6.131→8.022 ms;
they are different frames, not paired single-object measurements. Shutdown close
also fails to improve materially. There is insufficient benefit to promote it.

Use verified authored `backups/native-loading-compact-parts-rejected-v1.zip` to
revisit the measured implementation and its original-model fixture. The initial
rejection restored production files from `native-loading-fine-stream-spans-v1.zip`;
the later user-requested toggle restores the hash-verified candidate and adds
persistent native options wiring. Remaining targets are render publication/tree-entry
work and large unassigned engine waits; removing hierarchy wrappers alone has
not demonstrated a solution.
