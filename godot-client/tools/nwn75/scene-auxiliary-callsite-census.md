# NWN-75: original auxiliary Scene callsite census

Pinned original `nwmain.exe` SHA-256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`. This is a physical direct-call census for the other Scene side passes; the exact individual sites and targets are in `branch-ledger.json`. It complements [auxiliary scene passes](scene-auxiliary-passes.md), which records the main effects and geometry/API paths. The branch gates matter: a callsite in these bodies is not proof it executes in an ordinary frame.

| Body | Entry and nested work gate | Direct callsites | REA evidence |
| --- | --- | ---: | --- |
| `Scene::DoFog` `0x1400c7f10` | Fog state is set for a pass; cached shader/GL publication is downstream. | 5 | `ev_75304e5dfc6610bfa385a9cdb3a31a13f2b04d8248f0268accc067739183ddf9` |
| `Scene::FadeDoors` `0x1400c9320` | Door-model Gob, camera/door overlap, bounded alpha fade. | 17 | `ev_65b14b6b7ce72308524124fafa548a317adc1b06f84f3fa415bbcb4afa769f92` |
| `Scene::DoBinBucket` `0x1400c7580` | Scene `GrassIsEnabled`, active bin and optional sort/distance checks. | 25 | `ev_b0b68ab1f329ac737fd6a65ee403482c5c600671bc70aa551aaf152d9569f29d` |
| `Scene::DoTriggerBucket` `0x1400c8fa0` | Trigger bucket item with zero highlight byte. | 18 | `ev_e68abb6e26fc9638750f77d4c810b9b421a31c74bd0dae7f986014a35f18d5d5` |
| `Scene::DoHighlightTriggers` `0x1400c8930` | Highlighted trigger and pass flag; two opposite front-face stencil volume stages plus outline. | 59 | `ev_2c637a1db7883092cac5051f1bc7ca53640e9b3ad20df15392f188d59d0e0ba3` |
| `Scene::RenderBeams` `0x1400cceb0` | `enablebeams`, eligible distant light and admitted bucket `0xf` beam Part. | 23 | `ev_1766d9d23d6ff944e515db22dafb1b307e7b670ec63a769e0e1a002ddec9effd` |
| `Scene::RenderLines` `0x1400cf4c0` | Positive queued line-group count at Scene `+0xc8`; each nonnegative endpoint index supplies two vertices. | 23 | `ev_ae1931031a3cddf8157e9caae20371f9413466af8f99f68d7305cff9125bf756` |
| `Scene::RenderPaths` `0x1400cfcb0` | Internal `renderpaths` flag and Gob path points. | 26 | `ev_1c9d5fd6cfa526ebc7da3e94d08b883cfbea2cf3847087d2d8e26d9998232b15` |
| `Scene::RenderPersonalSpace` `0x1400d0080` | Global or Gob personal-space debug flag and positive radius. | 23 | `ev_38ddb8deb96e6e243ae10dd0731f287296819d21c9d48026585c5db55412faa0` |

These 219 direct sites are now represented individually. The previously resolved six computed sites remain site-backed: `DoBinBucket` Scene `+0x288=GrassIsEnabled` at `0x1400c75b7`; trigger bucket PartTrigger `+0xc8=Draw` at `0x1400c90fa`; trigger highlight PartTrigger `+0xf8=DrawVolume` at `0x1400c8b22/0x1400c8b46`; beam Part `+0x88=AsPartBeam` at `0x1400cd0c7` and admitted beam `+0xc8=PartBeam::Draw` at `0x1400cd126`. The Part `AsPartBeam` site is polymorphic: the base null and positive beam subtype differ, so the ledger retains candidate status for that admission.

The grass branch reaches `CAurTriangleBin::RenderGrassPolys` `0x14006d9e0`; trigger and beam branches reach their Part draw methods; debug lines/paths/personal space reach the mapped stream or vertex draw wrappers. Their child functions are separate descendants, some with incomplete direct-callsite coverage. State cache gates and imported GL leaves are recorded in [render-state boundaries](render-state-boundaries.md), [shadow state APIs](scene-shadow-stencil-apis.md), and [geometry/draw boundary](geometry-and-draw-boundary.md). The next concrete auxiliary descendants are `RenderGrassPolys` texture/material/stream work and `PartTrigger::DrawVolume` vertex publication.

## Grass draw child

`CAurTriangleBin::RenderGrassPolys` first requires a nonempty triangle-list array, then computes squared distance to the camera and rejects bins beyond its far radius or with zero resulting fade. It writes two grass material vectors via `Homogenize` at `0x14006daa9/0x14006dad0` and `RenderInterface::SetMaterialv` at `0x14006dab8/0x14006dadf`. `Homogenize` `0x14022cb70` copies Vector and alpha into process-global scratch `0x14140d1c0`; it has no callee or GL API (REA `ev_1b7004f2608debbfbc645958a2d79717ec128dea80182b868e187c87bbef66ba`). Material uniform publication is a later dirty-state path.

For each matching grass type with a positive count and existing VDO item, it calls the stored texture vtable `+0x100=CAurTexture::BindInUnit` at `0x14006db28`. It lazily looks up `vsgrass`/`fsgrass` at `0x14006db52` only if the shader cache is empty, then sets the program at `0x14006db66` and calls `RenderInterface::RenderVertexData` at `0x14006db86`. The seven direct calls and one typed texture dispatch are site-backed; the draw wrapper's `glDrawArrays`/`glDrawElementsBaseVertex` route is in [geometry/draw boundary](geometry-and-draw-boundary.md). REA `ev_d2e58f04787be8d0534f692a4986794a86bc3c281f4591aa49d40cb452159850`.

## Trigger volume child

`PartTrigger::DrawVolume` `0x1400f02e0` obtains or grows a shared indexed stream for `2 × trigger point count + 2` vertices and `6 × trigger point count` indices. It fills top/bottom vertices from the stored boundary and vertical offset, plus two center points; it constructs alternating-winding triangular sides. It calls `GetVertexData` at `0x1400f0359`, `GetElementData` at `0x1400f0368`, `CommitElementData` at `0x1400f0684`, `CommitVertexData` at `0x1400f06a0`, and `RenderInterface::RenderVertexStreamData` at `0x1400f06ca` for the indexed draw. `GetVertexStreamDataObjectTokenByAttributes` at `0x1400f0347` runs only when the shared stream is absent or too small. These six direct sites are in the ledger (REA `ev_fd708248871d7d8925ed2836de64b0788bccb72c1819edeebdeaae718d857c62`).

`VertexStreamDataObject::GetElementData` `0x1400bd630` calls `RenderInterface::LockPool` at `0x1400bd63e`, returning CPU element memory. `CommitElementData` `0x1400bd500` calls `RenderInterface::UnlockPool` at `0x1400bd505` with `2 × element_count` bytes. Their bodies have no direct GL call (REA `ev_722661abd075c172d9e562074c355577e7008dbe7f069f6eeed9244809e08d97`, `ev_530de94b00bc9fb7493bdf7090fc1fcd6c83fcdfd90ae57578ab929b661625ae`). Shared pool dirty/upload and indexed stream draw descendants are already mapped; their state gates decide which GL buffer calls occur.

The immediate grass/trigger child calls now have physical sites. Further work remains in generic pool/runtime descendants, debug-source producers, no-BSP/sky branches, and resource-provider boundaries.
