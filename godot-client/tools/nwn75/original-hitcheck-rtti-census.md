# NWN-75: original Part hit-test slot census

Pinned installed `nwmain.exe` SHA-256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`. The [reproducible scanner](audit-part-hitcheck-vtables.cjs) reads `+0x38` and `+0x40` slots from all 18 primary RTTI-backed Part vtables enumerated by the independent [Part Draw RTTI census](part-draw-rtti-census.md). The [ledger](original-hitcheck-rtti-census-ledger.json) records each `+0x40` candidate. This is complete for that specific RTTI-backed primary-table pattern, not for external code, RTTI-stripped tables, runtime-created objects or actual scene admission.

All 18 `+0x38` entries are `Part::HitCheck` `0x14008fd80`. The `+0x40=HitCheckGeom` target groups are:

| Target | Part subtypes | Immediate descendant |
| --- | --- | --- |
| `0x140090440` | Base Part, all five Emitter classes, Light, Camera, Reference, Projection, Shadow, Beam | Empty base geometry test. |
| `0x1400905b0` | TriMesh, Skin, DanglyMesh | [TriMesh bounds/face route](original-hitcheck-geometry.md). |
| `0x140090540` | AnimMesh | [Animated VDO face route](original-hitcheck-other-geometry.md). |
| `0x140090450` | AABB | [Recursive AABB node route](original-hitcheck-other-geometry.md). |
| `0x1400f06d0` | Trigger | [Flagged trigger polygon route](original-hitcheck-other-geometry.md). |

`Part::HitCheck` calls the virtual geometry slot from the current Part at `0x14008ff5c` and recurses into children through the common `+0x38` slot at `0x14008ffd5`, under the gates documented in [Scene/Gob/Part hit checking](lens-flare-hitcheck.md). A nonempty slot candidate does not prove that a given frame visits that subtype. The scanner's 18 table results match the ledger and the pinned executable bytes.
