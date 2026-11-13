# NWN-75: original `Scene::RenderSinglePass` branch map

This is original-binary evidence for `nwmain.exe` SHA-256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`. The render function begins at `0x1400d0f10`; REA retained analysis `ev_02ace6727b08cd03cb9bd9a012c7c646766c92f3bd0cd79bb2b383726b80c4a0` contains its 46 direct callees, 20 computed call sites and decompiled body. The table records order and gates in that body. A stage is not a leaf merely because it has a name; child traversal remains open.

| Order | Gate and input | Work / output | Original address |
| --- | --- | --- | --- |
| 1 | Scene name equals `mainscene` | Initialize current camera framebuffer resources. | `Camera::InitializeFrameBufferResources` `0x140059670` |
| 2 | Full dynamic lighting | Enable current LightManager lights through virtual slot `+0x10`. | `LightManager::EnableLights` `0x14007e890` |
| 3 | `enableshadows != 0` | Get shadow-light lists for modes 1 and 0 into Scene offsets `+0x60` and `+0x70`. | `LightManager::GetShadowLights` (direct, see retained analysis) |
| 4 | Always | Set fog, then perform the Scene virtual `+0x258` pass; enable blend and set blend function. When full dynamic lighting is disabled, enable dynamic-only lights through LightManager virtual `+0x18`. | `Scene::DoFog` `0x1400c7f10`; `Scene::Render...` slot `+0x258` `0x1400c9320` (`FadeDoors`); `LightManager::EnableLightsDynamicOnly` `0x14007ea70` |
| 5 | Always | Opaque bucket 0 with blend/alpha disabled and black color. | `Scene::RenderDrawBucket` `0x1400cd210`, type `0` |
| 6 | Always | Skyboxes, then transparent bucket 1 with blend/alpha enabled. | `Scene::RenderSkyBoxes` `0x1400d28f0`; `Scene::RenderDrawBucket` `0x1400cd210`, type `1` |
| 7 | Always | Bin bucket and tile-fade cap bucket 7. | `Scene::DoBinBucket` `0x1400c7580`; `Scene::RenderDrawBucket` `0x1400cd210`, type `7` |
| 8 | Always | Highlight gob, trigger bucket, trigger highlights. | `Scene::DoHighlightGob` `0x1400c8260`; `Scene::DoTriggerBucket` `0x1400c8fa0`; `Scene::DoHighlightTriggers` `0x1400c8930` |
| 9 | `enableshadows != 0` | Dynamic shadow pass; virtual `+0x218` takes `(this,0,1)`. | `Scene::RenderShadows` `0x1400d0ab0` |
| 10 | Either `renderpaths` or `renderpersonalspace` | Both debug draw functions are called. | `Scene::RenderPersonalSpace` `0x1400d0080`; `Scene::RenderPaths` `0x1400cfcb0` |
| 11 | Always | Dynamic geometry via Scene virtual `+0x220`. | `Scene::RenderDynamicGeometry` `0x1400ce110` |
| 12 | Bucket type 5 present | On `mainscene`, copy current camera subframe, then draw bucket 5. | `Camera::CopyRenderSubframe` `0x140057a20`; `Scene::RenderDrawBucket` `0x1400cd210`, type `5` |
| 13 | Focus object absent or present | Absent: emitter lighting only. Present: collect focus gob lights, then emitter lighting. | `Gob::CollectLights` and `LightManager::GetEmitterLighting` (direct, see retained analysis) |
| 14 | Always | Fade bucket 8. | `Scene::RenderDrawBucket` `0x1400cd210`, type `8` |
| 15 | `enableshadows != 0` | Static shadow pass through the same virtual slot `+0x218`. | `Scene::RenderShadows` `0x1400d0ab0` |
| 16 | `mainscene && enableFBeffects` | If full dynamic lighting disabled, enable lights; then run pre-water camera effects. | `LightManager::EnableLights`; `Camera::DoFrameBufferEffects` `0x140057b20`, phase `0` |
| 17 | Always | Set fog. If full dynamic lighting disabled, enable lights. | `Scene::DoFog`; `LightManager::EnableLights` |
| 18 | Bucket type 6 present | On `mainscene`, copy camera subframe; draw water bucket 6. | `Camera::CopyRenderSubframe`; `Scene::RenderDrawBucket`, type `6` |
| 19 | Always | Trigger highlights. | `Scene::DoHighlightTriggers` |
| 20 | `g_nRenderWireframe != 0` | Temporarily change color masks/polygon mode and replay buckets 0,1,7,8,2,3,5,6; restore state. | `Scene::RenderDrawBucket` `0x1400cd210` |
| 21 | Always | Additive bucket 4, beams, conditional light enable, emitter bucket, lens flares. | `Scene::RenderDrawBucket` type `4`; `Scene::RenderBeams` `0x1400cceb0`; `LightManager::EnableLights`; `Scene::DoEmitterBucket` `0x1400c7ae0`; `Scene::RenderLensFlares` `0x1400cea90` |
| 22 | `mainscene` | Post-water camera framebuffer effects. | `Camera::DoFrameBufferEffects` `0x140057b20`, phase `1` |
| 23 | Always, plus debug option | Drawable squares, Scene lines, optionally LightManager light ranges, final RenderInterface state. | `Scene::RenderDrawableSquares` `0x1400cdef0`; `Scene::RenderLines` `0x1400cf4c0`; `LightManager::RenderLightRanges` (direct) |

The Scene virtual slot resolutions above come from `Scene::vftable` at `0x140d8dd30`, referenced by `Scene::Scene` at `0x1400c0ca0`, with original PE pointer bytes. `LightManager::LightManager` at `0x14007d7d0` references `LightManager::vftable` at `0x140d85f70` (REA `ev_f725d501b73a5b5ca756a7e5740629a2b65a7c8050b8322da874b1fe52cefd66`); the original PE slot bytes resolve `+0x10` to `EnableLights` `0x14007e890` and `+0x18` to `EnableLightsDynamicOnly` `0x14007ea70`.

The bucket presence checks in stages 12 and 18 call `DrawBucketManager::HasItemsOfType` `0x1400d9ef0`. It reads the three per-face-list item counts for that bucket type and returns true on the first positive count; it has no callee or GL call (REA `ev_89b9a4a6125dfc7191d40bb954626557614318801d02c8f9a907b6c160c96c0d`). This only gates whether the subsequent camera copy and draw branch is entered.

All 20 REA computed callsites in this function are virtual dispatches using Scene or LightManager slots. Exact instruction inspection shows one `CALL [RAX+slot]` at each address; the 20 callsite-to-slot-to-target mappings are recorded in `branch-ledger.json`. REA's static callsite resolver alone reports each as unresolved, so the target resolutions rely on the constructors and original PE vtable pointer bytes. `NewCAurScene` `0x1400cb1c0` (REA `ev_319f3f17`) constructs a `Scene` directly, supporting this Scene vtable for GUI-created views. This does not establish runtime branch frequency or OS-thread identity.
