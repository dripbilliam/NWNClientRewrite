# Native TileData fog collection lower

Read-only research checkpoint,2026-11-06. No production collector is enabled.
The existing runtime keeps tile factor1 while this lower is unavailable.

The original binary is
`FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The retained Ghidra12.1.4 evidence below matches that exact binary. Source pins
and full original retained procedure text are copied without reanalysis to
`.cache/native-presentation-parity/loading-agent/native-collector-research-v1/retained-dossier.json`
(SHA256`711400253674ca6d7c2c80c7c006e1955af9081bafb94193502f788a03a61be4`).
The adjacent `exports.json` is a fresh bounded read-only PE export-directory
projection, not decompiled implementation evidence.

## Established native ownership

| Procedure | Evidence | Relevant behavior |
| --- | --- | --- |
| `ManageSceneBSP0db320` | `ev_09d80d9119302b831669f89420d3bae5e7a0578e74b2e20ff5ac6f593308b6a1` | Traverses scene root`+188`, camera native XYZ`+b0` and camera plane list`+4f0`, with callback`0dc140` |
| `BSPTraverseVolumeApprox229dc0` | `ev_efc35458ae38284c80ef29426391194188ae68dcec4dc450bb62437b1e189ce1` | Calls the node callback before its leaf test; partitions/prunes the plane list using retained split vertices, then orders children by camera side |
| Collected-node callback`0dc140` | `ev_45e32deb3c08e2049d65115dfbffa713fea199a454c49b479334e1e1653ddc01` | Reads node data`+70`, then TileData pointer`data+98`; increments unfogged TileDataC8 before `ProcessTriMeshParts` fine culling |
| `SceneBSPAddTileData0dd340` | `ev_4ab185511a1832552f2aab60acf7a36d2dfd7188a71056b6fc7eb5b2967e83c2` | Uses `BSPFitSphere(root,actual placement,0)` and writes this exact node's `data+98`. Meshes and other Parts are independently fitted to their own nodes |
| `BSPFitSphere229690` | `ev_e2ba6c92fbcf634cb43b73ab1adfc203942898a75a099e65bfcc1d2776a7e7b6` | Tests native split-plane distance; radius0 equality chooses negative child`+10`, positive distance chooses`+18` |
| `Scene::SpawnTile0d41a0` | `ev_0cdf2929555a1f88661105867841e26d91aadf548ff94fea7b7b57e660b9f172` | Reuses `SceneBSPGetTileData(placement)` or constructs TileData, records actual placement at`TileData+48`, then calls `SceneBSPAddTileData` |
| `Camera::RenderScene05a5d0` | `ev_4393914dd018195bd1a10f8edf54a40ad4cff9b0c8d0e56fa03049d3137f7161` | Constructs6 view-volume planes, rotates their normals by camera quaternion`+bc`, translates distance by native camera XYZ`+b0`, then publishes CurrentCamera |

The fog increment is therefore a **collected BSP node callback**, independent of
whether a Part later survives fine culling or draws. Godot visible-mesh callbacks,
Part bounds, projected tile rectangles and room/portal guesses cannot supply it.
An empty-mesh node with a TileData still participates. Native traversal may call
the callback on an internal node as well as leaves. Its occurrence order is the
source boundary; no global per-frame deduplication is established by this code.

At callback`0dc140`, the exact ordered conditions are TileData exists, C8<1 and
C4==0. The update is `f32(C8 + f32(DeltaT*4))`, upper-clamped1. It occurs before
`ProcessTriMeshParts`, whose separate Part/sphere/box tests must not gate C8.

## Traversal and camera inputs

`229dc0` uses the BSPNode split plane at`+0..+c`, negative/positive children at
`+10/+18`, leaf marker`+20`, split-vertex array/count at`+60/+68` and node data at
`+70`. Internal nodes hold two reduced plane lists at`+40/+50`. Incoming planes
are inspected in reverse order. Native vertex-plane signs distinguish all
negative, all nonnegative, and crossing. Crossing planes reach both children;
other cases retain or prune the relevant child, using the dot product of the
frustum normal with the split normal. Equality and f32 arithmetic matter. When
a child's reduced list empties, the original switches to the camera-ordered
`BSPTraverse229cb0` overload, rather than fine-testing every mesh in that branch.

Perspective projection uses actual viewport aspect, vertical angle`+4c8`, near
clip`+4d0` and far clip`+4d4`. Local near/far planes start as `(0,0,1,near)` and
`(0,0,-1,-far)`. Four side planes are constructed from rays with
`x=±f32(tan(angle/2)*aspect)`, `y=±tan(angle/2)`, `z=-1`, using native `NormalOf`.
Every normal is rotated by the source camera quaternion; its world plane
distance is adjusted by `d -= dot(normal,cameraNativePosition)`. The retained
code also has an orthographic branch; that cannot silently reuse perspective
frustum math. Render viewport overrides can change the effective aspect.

The replacement's established position conversion is native `(x,y,z)` to Godot
`(x,z,-y)`. Its inverse is `(gx,-gz,gy)`, also applicable to world normals.
For a future collector reading the actual Godot camera, the derived mapping is
to apply that inverse world-axis conversion to the final camera basis and
position. Camera-local view rays retain their local axes. Applying the object
geometry quaternion conjugation a second time would change the camera-local
view convention. This camera mapping is an inference from the two source
contracts; it still needs differential projection fixtures before activation.

## Concrete integration route and remaining proof

1. Reproduce the original area BSP construction, including split planes,
   split polygons, leaf decisions, dimension ordering, cell size and depth.
   Native client area initialization calls scene virtual`+28` with received
   dimensions and third argument5. A fresh PE projection resolves the missing
   builder to `Scene::InitBSP0ca3b0` and `BSPNode::BSPNode229420`. Their symbol
   names alone do not establish the construction algorithm.
2. At actual tile publication, bind the same TileData/map index through the
   exact placement/radius0 node lookup. Keep it independent of the tile mesh,
   batching, bounds and later draw admission. Replacements/retirement retain
   the existing area/lifetime fences.
3. At each owned main-world collection boundary, capture the actual current
   camera's effective viewport/projection and final native world transform.
   Run the exact native tree traversal and its ordered callback occurrences.
   A generic engine frame signal is not proof of the same collection boundary
   for multiple viewports, portrait cameras or repeated renders.
4. Pass those collected TileData occurrences and the existing native renderer
   DeltaT to the existing fog lower. The current world snapshot fade getter is
   a separate established owner; a substitute GUI/OS/process delta is not
   justified by the collector code. Publish only changed factors through the
   already-tested material/batcher endpoints.
5. Verify native split-boundary equality, all/crossing/no-plane cases, empty
   geometry, offscreen/fine-culled Parts, camera rotation/aspect/resize,
   orthographic behavior, repeated traversals, tile retirement and transition.
   Static port tests alone do not close the final matched native-client check.

The owned REA import completed. New exact construction/ordered traversal
dossiers are retained in `evidence/native-tile-fog-collector-build-v1.json`.
`InitBSP` is `ev_f9465144dd717f19857585fc77d357d45bbad4300c29525f41dc4de318167c52`;
its inner builder`0d63d0` is
`ev_33548ea4a8f69639983716e097fb53660e92f124ab67c78e0cf779f3b1277716`.
The tree has6 outer bounding-plane nodes/outside leaves, then the padded XY
grid. The inner builder splits the larger remaining dimension (ties choose X),
floors its geometric midpoint to the cell-size grid, and recurses with floor/ceil
half cell counts. Inner leaves have marker2. Six outer planes wrap the grid;
their exterior leaves have marker1. Bounds are
`(-margin*cell,-margin*cell,-30)` through
`((width+margin)*cell,(height+margin)*cell,(max(width+2margin,height+2margin)+1)*10)`.
The upper Z uses literal10, independently of the configurable cell size.

The actual client-area call at`7dca21..7dca43` pins margin5, auxiliary bins=true,
cell size10. Stack`+28` receives float10 from original constant`d8216c`, stack`+20`
receives byte1, R9D=5, R8D=[area+10], EDX=[area+c], then virtual`+28`.
Its retained original Listing view is
`ev_d111acfe20851b1d71bab798aaa81517f4a8e2f56fa5fbd3e791d99d177b9727`.

The camera-ordered zero-plane overload`229cb0` is
`ev_55f9735c84cc547b458a5d568c7ab6245aed8d40611a2db422b8c77fcb7efbe5`.
It passes an empty plane list to its callback and visits camera-far **before**
near. This differs from `229dc0`'s near-first volume recursion and must remain a
separate path.

Native renderer DeltaT is now pinned too: original main update`6db800`,
instructions`6db9b7..6db9d5`, read the same primary Client+50 timer's snapshot
difference via`597050`, take its **low signed32** bits (`MOVD/CVTDQ2PS`), divide
as f32 by1000000 (`DIVSS`), then store global`14128e030`. This is distinct from
the fade reducer's whole-millisecond conversion even though they share a
snapshot owner. No new clock or GUI/process delta is needed. Exact Listing view
`ev_ebe0767da57bdb42834b082707e5e4c0b0f45ce857de79fc09d8665593a959c4`
and store instruction
`ev_8f7d0005f5a17f3a9183103a5c6399a6da3833cbbbb28cf907f793269065aad3`
retain the original operation sequence. The byte-template candidate search was
only a locator; the decoded Listing provides actual write evidence.

## Isolated original-instruction differential proof

`capture_bsp_collector_oracle.py` executes the original pinned instructions in
Unicorn. Only allocator/memory, draw API setup, auxiliary bins, clock-return and
callback boundaries are captured. It executes native construction, node data,
radius0 TileData fitting, volume traversal, zero-plane ordered traversal, camera
plane math and renderer DeltaT conversion. This is an instruction oracle for
synthetic POD inputs, not an original renderer or viewport acceptance run.
Camera `tanf` explicitly selects the original SSE branch. The alternative
AVX/FMA branch remains an explicit lower; no host `tan` is substituted.

The immutable `native-collector-oracle-v4/corpus.json` contains5 differently
shaped/padded trees,987 nodes,35 traversals,15 cameras and11 signed snapshot
cases. It includes native duplicate TileData aliases and35 radius0 exact
split/outer-boundary probes. The separate GDS oracle in `bsp_collector.gd`
passes7,294 checks in `native-bsp-collector-v3/run.json`. The original v1
differential exposed signed-zero ordering on margin0 outer planes; that
failure and its receipt remain preserved. No production code uses this helper.

Retained exact camera/normal/quaternion/normalization/SSE math and actual
area/clock callsite facets are saved in
`evidence/native-tile-fog-math-and-inputs-v1.json`, with original Evidence IDs
and binary identity. Decompiler text is not treated as original source; the
inline `NormalOf` cross product in Listing is necessary because the recovered
pseudocode misses the hidden output argument.

## Separate bounded POD kernel

The GDS cached32×32 traversal measured13.94ms median in the original v2
receipt. Root explicitly declined activation at that cost and authorized the
separate extension in `kernel/bsp_math.hpp` and `kernel/bsp_collector.cpp`.
`build_bsp_collector_kernel.ps1` stages a private MSVC `/O2 /fp:strict /W4 /WX`
build. It changes no engine, particle or highlight implementation or binary.
The accepted build is `bsp-collector-kernel-build-v3/build.json`.

The static `NwnBspCollector.collect` call borrows packed immutable f32 split
planes/vertices, integer topology/ranges/membership, a native camera position,
already-bound camera planes and the explicit unsigned low32 snapshot word.
It returns detached ordered node IDs, reduced plane counts, TileData tokens,
their node IDs and the exact signed-low32 renderer DeltaT word. There are no
Nodes, entity/clock authority, retained inputs, callbacks to game state, files,
network or OS clock in the kernel. It preserves duplicate occurrences. It
validates dimensions/ranges, finite inputs, graph cycles, depth128,
callback600000, node300000 and plane64 limits. Capacity violations return
unavailable; neither deduplication nor a generic frustum substitutes for native
traversal. The small accepted DAG fixture explicitly proves shared-child
callback multiplicity; a larger DAG proves the callback bound.

`bsp_collector_kernel.gd` is an isolated static adapter. Cold construction and
radius0 placement use the proved GDS oracle. Every collection requires the
separate native extension; absence returns unavailable, with no silent GDS
traversal fallback. Its externally supplied source scope guard runs before and
after a collection. The adapter revision rejects results when publication
reenters and replaces a physical tile or retires the scope. A tile's explicit
physical lifetime can own multiple node memberships. ID reuse clears only
that physical owner's memberships; stale retirement cannot erase a successor.
The extension receives packed numbers only. Native camera position, plane
authority, tile placement, physical lifetime and primary snapshot words still
must be supplied by the actual source owners before production integration.
Timing probes in this adapter are profiling only and never supply renderer
DeltaT or fog state.

`check_native_bsp_kernel.mjs native-bsp-kernel-v3 stage|run` stages a private
CPU project with pinned sources/original corpus/private DLL and reviewed
single-precision engine. The accepted receipt has7,373 native/differential/
identity/reentry/bounds checks plus3 missing-extension checks, exits0,
errors[], sourceChanged[] and liveSourceChanged[]. The full camera6plane
math + source guards + gather + kernel validation/traversal + detached output
measurement for one32×32, margin5 cached tree (3,539 total nodes,977 callbacks)
is145–381µs, median155µs over31 samples. The simpler prebound-plane adapter
plus test-only array unpacking is143µs median over9 samples. These are bounded
headless CPU costs with an original SSE tangent word already cached, not FPS,
frame scheduling, GPU rendering or whole-game performance claims.

Production hooks and fog activation remain outside this checkpoint. Factor1
remains active. Before activation, prove the actual `SpawnTile`/`AddTileData`
position/height lower and the `DrawBucketTileData` association for every
affected Part/model, including static state geometry and parent nodes with no
TileData. Current terrain material endpoints alone do not establish matching
static geometry, placeable or actor participants.
