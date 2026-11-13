# NWN-75: AABB model payload to hit check and debug draw

Pinned original `nwmain.exe` SHA-256: `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`. This supplement follows model node `aabb` / binary kind `0x221` from text or binary payload into `PartAABB` and its CPU or conditional GL consumers. Exact original sites and REA IDs are in `model-aabb-payload-ledger.json`. The surrounding model entry path is in `model-name-parser-tree.md`.

## Text AABB tree

`ParseNode` `0x1400a0d90` selects `MdlNodeAABB::MdlNodeAABB` `0x140087360` at `0x1400a0ff6`. It constructs a TriMesh base, sets kind `0x221`, initializes tree pointer `+0x2c8` to null, and installs AABB parse `+0x8=0x140092300`, instance `+0x28=0x140092250`, and vertex generator `+0xa0=0x1400922f0`. Its postprocess and temporary cleanup fields are inherited from TriMesh. The text parser calls `+0x8` per line and `+0x10` at `endnode`, as detailed in the model parser supplement.

`MdlNodeAABBParseField` tail-jumps to `MdlNodeAABB::InternalParseField` `0x140099be0`. After the bounded, case-insensitive first-token check, an `aabb` line invokes `Parse(char const*, AABB*&)` `0x1400a03f0` into node `+0x2c8`; other/shared fields continue through `MdlNodeTriMesh::InternalParseField` `0x14009e950`. The AABB parser trims spaces/tabs, scans six floats and up to two integers, and allocates a 0x30-byte CPU node. It places minimum/maximum vectors at `+0x0..+0x14`, a face index at `+0x28`, and split/direction flags at `+0x2c`. If the face index is `-1`, it reads two more resource lines and recursively fills child pointers `+0x18` and `+0x20`. With exactly seven scanned values it derives split direction from child box centers; otherwise it uses the eighth authored integer. Leaf nodes stop recursion. The text reader terminates in CPU allocation and `AurResGetNextLine`, with no GL call.

## Binary AABB tree and ownership

Binary reader `FUN_14007abe0` selects kind `0x221` from source `+0x6c`, allocates a 0x2d0 TriMesh-derived node, and calls shared node/mesh readers `0x140078ab0` and `0x14007be10`. A nonzero source offset `+0x270` is added to the binary data base, then a 0x30-byte root AABB record is copied into node pointer `+0x2c8`. Each record carries six floats at `+0x0..+0x14`, child relative offsets at `+0x18/+0x1c`, face index `+0x20` copied to CPU node `+0x28`, and split flags `+0x24` copied to `+0x2c`. `FUN_14007a3d0` recursively allocates and copies children at each nonzero offset; zero child offsets stop that branch. The binary node installs the same AABB parse and instance targets as text, plus shared TriMesh postprocess/cleanup and the AABB vertex generator. The arithmetic establishes the offset provenance; malformed offset/count handling remains open.

`MdlNodeAABB::~MdlNodeAABB` `0x140089230` follows owner pointer `+0x2c8`, recursively frees both child branches via `FUN_14008a740` `0x14008a740`, frees the root AABB node, then runs TriMesh destruction. Thus the tree is owned by the model node, while a `PartAABB` keeps a pointer back to that model node. The AABB-specific `InternalDestructor`/destructor callback also descends model child nodes; the AABB tree free itself is in the C++ destructor path.

## Mesh and typed Part

The inherited TriMesh postprocess `0x1400931b0 → 0x1400a9ae0` runs `ProcessVerts` when vertex count `+0x284` is zero. With positive face count `+0xb8`, its `+0xa0` call resolves to `MdlNodeAABBGenVertices` `0x1400922f0 → 0x1400a7d40`. The generator creates per-corner `NodeVertex` CPU records, reuses vertices on matching face data, rewrites indices, and removes degenerate faces. Shared postprocess then builds neighbor/vertex indices, generates render-pool vertex data, computes tangent basis and face area through a pool read, and invokes shared temporary cleanup. A preexisting vertex count takes the tangent-only branch. This is model preparation, not an unconditional per-frame draw.

`CreateInstanceTreeR` calls node `+0x28`, resolving for AABB to `MdlNodeAABBCreateInstance` `0x140092250`. It allocates a 0xc0 `PartTriMesh`, runs that base constructor and installs `PartAABB` vtable. `PartInitMaterial` tests `AsPartAABB` at `0x14009395e` after Skin/AnimMesh/Dangly tests; a positive result constructs a `VertexPrimitiveFlat` and assigns the `VertexPrimitiveAABB` vtable. The primitive stores in Part `+0x90`. `model-instance-branch.md` covers the surrounding instance traversal and material path.

## CPU and GL consumers

`PartAABB::HitCheckGeom` `0x140090450` takes the model node at Part `+0x8`, verifies its `0x221` type bits, passes AABB tree pointer `+0x2c8` to `HitCheckAABBnode` `0x140090170`, and returns a CPU hit result. The recursive helper rejects whole boxes, visits children, and at eligible leaves reads a vertex pool and performs polygon intersection. `original-hitcheck-other-geometry.md` maps those gates and CPU leaves in detail. `Scene::AddFacesToBins` independently tests the AABB Part subtype and, when enabled, turns eligible grass faces into CPU bin data; `scene-lifecycle-area-entry.md` covers that path. These are data-dependent consumers, not assertions that every AABB node is drawn.

`PartAABB::Draw` `0x1400a1c70` returns unless `currentscene` exists and its `+0x1e0` flag is enabled. With an active Part and valid mesh, it locks position/color pools, fills a vertex stream by face color, and submits paired front-face draws through `RenderInterface::RenderVertexStreamData`. The downstream imported GL draw calls are in `part-draw-subclasses.md` and `geometry-and-draw-boundary.md`. Ordinary frames with the scene flag off stop before this GL route.

## Open boundaries

- Shared TriMesh field parsing, binary mesh streams, material loading, and render-pool publication are linked to their existing maps. Their individual formats are outside this subtype supplement.
- Text scan failure, null allocation, malformed binary child offsets, and cycles in binary child references are not established as safe by the normal-path static evidence.
- The scene flag's producer and exact frequency of collision, grass-bin or debug-draw calls are not proved here. The static path establishes conditional handoffs only.
