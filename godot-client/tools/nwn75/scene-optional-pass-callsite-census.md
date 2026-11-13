# NWN-75: original optional scene pass callsite census

Pinned original `nwmain.exe` SHA-256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`. This census records physical direct-call sites in seven original Scene pass bodies. `branch-ledger.json` contains each site and its target, including state, stream, geometry, scope, and runtime helpers. The entry gates below distinguish optional work from ordinary unconditional rendering. The table is not a performance measurement or a claim of closed descendants.

| Body | Entry and important gates | Direct callsites | Original REA evidence |
| --- | --- | ---: | --- |
| `Scene::DoHighlightGob` `0x1400c8260` | Called in `RenderSinglePass`; substantial work requires a positive Scene highlight count and highlight texture. Each highlighted/attached Gob needs an eligible Part tree. | 38 | `ev_4b3f5f7c91ac25cd3d4a04937f20eb41a1bacd8412d489062083ef814f4fba49` |
| `Scene::RenderLensFlares` `0x1400cea90` | Called after additive/emitter work; obtains flare lights and applies per-light range, BSP and `HitCheck` occlusion, then visibility fade before each authored texture quad. | 41 | `ev_918a05e5605f45db2f6455a7a1fae6f6faa407c18e4b313c210dd2360c3830e1` |
| `Scene::RenderShadows` `0x1400d0ab0` | `RenderSinglePass` enters only when `enableshadows`; dynamic/static mode, shadow geometry flags, light radius and debug-volume flag choose subpasses. | 46 | `ev_5340b45e1ceeab16641cc9349bac868b7d471434ad4f4392251d0041e28eef44` |
| `Scene::RenderDynamicShadows` `0x1400ce3a0` | Selected shadow-light bucket, cached shadow shader and admitted TriMesh primitive with pending elements; stream commit happens before shader gate. | 29 | `ev_ebe848986636b24851eb3c828cd531ee8501c623fdf724e02e5b5de27da8736e` |
| `Scene::RenderStaticShadows` `0x1400d2ca0` | Current static light, shadow bucket 9/10 and admitted PartShadow. | 21 | `ev_82fdf03a9b086fd25577881f3511f9668bd51ff485a5ca0e63e853afc1d086ee` |
| `Scene::RenderShadowPlanes` `0x1400d0350` | A light with an eligible plane/radius reaches stream construction, shader/state setup, commit and draw. | 27 | `ev_f521b02b49aa40df1ea8ff3e9e4ea4030d8bb3cdf05ad4f54ec71c4b3d96f70b` |
| `RenderDrawableSquares` `0x1400cdef0` | Final Scene pass consumes the queued square list after setting its simple render state. | 19 | `ev_eb4e15b6f520cd0fad11bd1f5243014dca3d2c7480b6130fe80df78771a43cfa` |

These 221 direct callsites are now site-backed. Parent entry conditions and geometry routes are detailed in [single pass](render-single-pass.md), [shadows and dynamic geometry](shadows-and-dynamic.md), and [auxiliary passes](scene-auxiliary-passes.md). The calls include `RenderInterface` wrappers that reach the separately mapped GL state and draw boundaries; a direct state wrapper call is not itself a draw. Scope instrumentation and allocator/math calls are preserved as real children, with their own descendant classification still partial.

Shadow stencil/depth wrapper gates and imported GL sites are recorded in [shadow state APIs](scene-shadow-stencil-apis.md).

## Shadow pass computed calls

`RenderShadows` has six additional computed Scene-vtable calls, now site-backed rather than represented only by unsited endpoint pairs:

| Site | Resolved slot target | Condition |
| --- | --- | --- |
| `0x1400d0c4e` | `+0x1c0` → `Scene::DoGobShadows` `0x1400c7f90` | Dynamic light; `shadowdynamicgeom` |
| `0x1400d0c66` | `+0x1d8` → `Scene::DoDynamicMeshProjections` `0x1400c7910` | Dynamic light; `shadowstaticgeom` |
| `0x1400d0d20` | `+0x1c8` → `Scene::RenderStaticShadows` `0x1400d2ca0` | Static mode; `shadowstaticgeom` |
| `0x1400d0dc5` | `+0x1c8` → `Scene::RenderStaticShadows` | `g_nRenderShadowVolumes` debug repeat |
| `0x1400d0dfe` | `+0x1c0` → `Scene::DoGobShadows` | Debug repeat; `shadowdynamicgeom` |
| `0x1400d0e16` | `+0x1d8` → `Scene::DoDynamicMeshProjections` | Debug repeat; `shadowstaticgeom` |

The vtable targets and downstream projection/Part subtype gates are evidenced in [shadows and dynamic geometry](shadows-and-dynamic.md). The original `RenderShadows` body above proves the callsites and their branches. `RenderDynamicShadows`' one computed Part `+0x58` call, `RenderStaticShadows`' two Part calls, `DoHighlightGob`'s nine Gob/texture/Scene calls, and `RenderLensFlares`' two Scene/texture calls were already resolved in their respective documents and stay separate from the direct census.

## Flare selection and shared stream helpers

`LightManager::GetLensFlareLights` `0x14007f290` resets its cached flare-list count and scans its current light array. It admits a light when its associated model-node authored flare count at `+0xe0` is positive; only a full destination list calls `_realloc_base` at `0x14007f319`, doubling capacity or starting at 16. It returns the cached list to `RenderLensFlares` and performs no draw or GL call itself (REA `ev_142e4bc238d6d42994fd3e8709ab3b2e260e4c276e6bed42e8cc73fe9bcfe327`).

Highlight, lens flare and shadow-plane vertex streams share `VertexStreamDataObject::GetVertexData` `0x1400bd890` and `CommitVertexData` `0x1400bd5d0`. The former calls `RenderInterface::LockPool` at `0x1400bd89e` to return CPU stream memory; the latter calls `RenderInterface::UnlockPool` at `0x1400bd5db` with `vertex_count × stride` bytes and the caller's flags. Their wrapper bodies contain no direct GL call. The pool implementation's dirty-range and conditional buffer publication are mapped in [primitive/VDO preparation](primitive-vdo-preparation.md) and [geometry/draw boundary](geometry-and-draw-boundary.md). REA `ev_0e0081224d718d8f2cf059862381ea182b3641380a3a840e358cbd337072c505`, `ev_71e930d1efbf7426cd7d3969222610941cc416b18acb16119d2f7887e428c1e6`.

`RenderShadowPlanes` uses `FUN_140c7d6d8` at `0x1400d0588` as an original `sqrtf` runtime helper. Ordinary finite, nonnegative input takes the square-root return in that body; NaN and negative/special inputs call `_handle_nanf` at `0x140c7d707` or `FUN_140caeb60` at `0x140c7d751`. These two runtime descendants remain open, but the helper is CPU math, not an extra shadow draw (REA `ev_388be500fb4be7cacb9e6f84cdc3ba0e0dd2f40ae59ca3ba0a0a4aff1f466d71`).

## Open descendants

The immediate direct and computed calls of these seven bodies are recorded, but their deeper helper trees remain partial. The next concrete world-side work is to follow shadow-plane stream/state publication and the highlight/flare stream draw wrappers into any still unclassified helper or GL leaf, then reconcile optional path source data and shared math/allocator leaves. The [world frontier](scene-world-frontier.md) tracks these alongside projected geometry, no-BSP/sky, and resource-provider boundaries.
