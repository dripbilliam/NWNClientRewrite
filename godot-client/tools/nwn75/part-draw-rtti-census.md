# NWN-75: original Part Draw vtable census

Scope: pinned installed `nwmain.exe`, SHA-256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`. `Scene::RenderDrawBucket` calls Part virtual `+0xc8` at `0x1400cd8d1`; `Gob::PartDraw` calls the same slot at `0x1400a34e7`. A slot target is a candidate for a Part object of that subtype, not proof that it enters a particular bucket or frame. The [census script](audit-part-draw-vtables.cjs) scans every initialized `.rdata` pointer for a valid MSVC complete-object locator, follows its class hierarchy, retains primary vtables whose hierarchy includes `Part`, and reads the pinned `+0xc8` qword. The [ledger](part-draw-rtti-census-ledger.json) records all 18 rows. This is complete for that **RTTI-backed primary-vtable pattern**, not for runtime-created objects, RTTI-stripped tables, or external code.

| Part subtype | Primary vtable | `+0xc8` target | Known role |
| --- | --- | --- | --- |
| `Part` | `0x140d87f08` | `0x1400a1c60` | Empty base Draw. |
| `PartEmitter` | `0x140d84400` | `0x1400a1c60` | Inherits empty Draw; emitter rendering uses the separate Scene emitter route. |
| `FountainEmitter` | `0x140d84518` | `0x1400a1c60` | Same inherited Draw. |
| `ExplosionEmitter` | `0x140d84630` | `0x1400a1c60` | Same inherited Draw. |
| `SingleEmitter` | `0x140d84748` | `0x1400a1c60` | Same inherited Draw. |
| `LightningEmitter` | `0x140d84860` | `0x1400a1c60` | Same inherited Draw. |
| `PartCamera` | `0x140d88108` | `0x1400a1c60` | Same inherited Draw. |
| `PartReference` | `0x140d88208` | `0x1400a1c60` | Same inherited Draw; referenced Gob can render through its own recursive Part tree. |
| `PartLight` | `0x140d88008` | `0x1400a2480` | Empty Light Draw. |
| `PartTriMesh` | `0x140d88308` | `0x1400a24c0` | Material/primitive route. |
| `PartSkin` | `0x140d88438` | `0x1400deb40` | Skinning and bone state route. |
| `PartAnimMesh` | `0x140d88568` | `0x1400a2150` | Animated mesh primitive route. |
| `PartDanglyMesh` | `0x140d88698` | `0x1400a22d0` | Dangly mesh primitive route. |
| `PartProjection` | `0x140d887c8` | `0x140c42254` | Guarded computed-call/error trampoline; no established draw submission. |
| `PartAABB` | `0x140d888d0` | `0x1400a1c70` | Flag-gated debug AABB stream route. |
| `PartShadow` | `0x140d8fe88` | `0x1400a2490` | VDO vertex-data route. |
| `PartBeam` | `0x140d8ff90` | `0x1400a22a0` | VDO vertex-data route. |
| `PartTrigger` | `0x140d91840` | `0x1400f0210` | Alpha-gated raw-vertex route. |

There are **18** RTTI-backed primary tables and **11** distinct Draw-slot addresses. The previous ten-target subset in [geometry and draw boundary](geometry-and-draw-boundary.md) covers every demonstrated GL-submitting Draw body. The eleventh slot is the `PartProjection` trampoline: its pinned vtable qword at `0x140d88890` is `0x140c42254`. Ghidra shows that body decodes a guarded function pointer from globals, conditionally calls it, then enters nonreturn error helper `0x140c8a600` (`ev_25e6c5225cac1563219ee95245ab26e51b4c0bb0fd7fd0c189b87ba557e4af7a`). It is not a proven GL leaf or an ordinary mesh Draw. `PartProjection::PartProjection` `0x140087ed0` stores this table while copying mesh and light fields (`ev_ddc9ff058cd6e4b563a1ef2e36c11df5a5d26517497ee59b77b7a387a21533e3`). The bounded direct-reference scan finds two calls to that constructor: `0x1400d8293` and `0x1400d82da` in `0x1400d7f00`. Each is immediately followed by a store of the derived PartShadow or PartBeam table to the same object; pinned bytes at `0x1400d828c`/`0x1400d82d3` show `E8 ... 90 48 8D 05 ... 48 89 07`. The observed direct producers therefore replace the base trampoline before publication. Indirect or inlined producers and actual dispatch into this slot remain unproven.

The pinned RIP-relative store census finds an executable `LEA`/`MOV` site for every listed table. Examples: `PartEmitter` table load at `0x140060441`, Fountain at `0x1400603be`, Explosion at `0x14006038e`, Single at `0x1400606ee`, Lightning at `0x1400603ee`; `PartCamera` at `0x1400918d2`, `PartReference` at `0x140091b62/0x140092eb2`, and `PartProjection` at `0x140087f2b`. These are table-write sites, and some can occur in destructors: `PartReference` at `0x14008acfa` is its deleting destructor, not a constructor (`ev_d2f0c87799fb85260b187887871448bd73d5a423d3ba57babbd496968a072f7b`). `MdlNodeCamera::InternalCreateInstance` `0x140091860` allocates a PartCamera and installs its vtable (`ev_b9b0646c2a1241675f7f23e33802ccf0d561bf75683fff6c4b51ad1a0114a476`). `MdlNodeReference::InternalCreateInstance` `0x140091af0` and `MdlNodeReferenceCreateInstance` `0x140092e40` each allocate a 0x78-byte PartReference and install its table (`ev_f0e07e8525c1a01f4a6c6792d70788f41896977ae91801f44565e900bf313008`, `ev_b544bc319b305877af32f0763b1f4f5d1449e9bf55634bc1448f0e9a6efd7788`). The model/Part factory and referenced Gob ownership are in [model instance construction](model-instance-branch.md) and [non-emitter animation](original-scene-animation-nonemitter.md); emitter subtype production and rendering are in [particle effects](original-particle-effect-render.md).

The model instance tree calls each authored node's `+0x28` creation function and recursively attaches the returned Part. The constructor-backed function-pointer family covers AABB, AnimMesh, Camera, DanglyMesh, Emitter, Light, Reference, Skin, TriMesh and Trigger nodes; the normal Trigger instance function returns null, while another Trigger constructor path exists. Emitter creation chooses its subclass from authored update data. These are producer gates for the vtable set, not evidence that every Part type enters a draw bucket. The [model instance map](model-instance-branch.md) contains the node-function sites and evidence.

The TriMesh, Skin, AnimMesh, Dangly, AABB, Beam, Shadow and Trigger Draw bodies join the already mapped [geometry/API route](geometry-and-draw-boundary.md) and [subclass continuation](part-draw-subclasses.md) under their respective material, asset and visibility gates. Camera, Reference and emitter families add no new GL route through the `+0xc8` Draw slot. Static evidence cannot determine a live model's Part subtype mix, which Scene draw bucket admits it, or every possible producer of the `PartProjection` base table. Those remain explicit dynamic frontiers.
