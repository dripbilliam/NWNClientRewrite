# Installed GUI_ICON item template and source map

This maps the **installed NWN root plus Prelude.nwm** resource bindings. It does not establish what a later Arelith NWSync/HAK override contains. The native copy-model path selects the `L/LC`, `R/S/RC/SC`, or `ARMR#L/S` template family, binds named `gui_replaceNN` textures, and attaches the resulting GUI model to its owning panel's scene. The current Godot `gui-icon-v1` decoder was used here for a structural census; this is not a visual acceptance result.

## Template census

`ResourceCatalog.resource_names(2002)` finds 376 `gui_icon_*` models. Of these, **372 are item-icon templates**: 120 large `#x#L/LC`, 120 small `#x#R/S`, 120 small composite `#x#RC/SC`, and 12 armor `ARMR1..6L/S`. All 372 decoded without error when supplied the expected count of original replacement layers. The remaining four are `1x1M`, `1x1MRNG`, `METAMAG`, and `MINIMAP`; `1x1MRNG` references `gui_rad_ring` and `METAMAG` is animated, so this structural `gui-icon-v1` probe did not decode those two as item templates.

Across the 372 item templates there are **760 render meshes**. Every sampled local mesh is planar (`z` range zero), has six triangle indices, and has either four or six vertices. No decoded item template has a clip or a quaternion tilt around X/Y. Planarity does **not** make transforms disposable: 91 meshes have meaningful X/Y node translation, nine have Z rotation, and composite/armor meshes use parent chains and successive depth offsets. **617 meshes crop their UV range**; 13 extend U slightly beyond 0–1. The tall `1x3` and `2x3` L/LC templates reach about U=1.01 and V=0.25–1; `1x5` and `2x5` templates start at V=0.375. Armor L/S templates start at V=0.25. Output must use the actual model geometry, transform chain, depth, UV, and sampler.

The **179 composite L/RC/SC templates** contain an authored exception: **50 have three render meshes but all three reference `gui_replace01`**. Their native creation path still binds three replacement slots. The model's per-mesh texture name decides which slot is drawn; assigning slot 01/02/03 by mesh ordinal would alter these models. All 12 armor templates have one through six meshes with sequential `gui_replace01` through `gui_replaceNN` references.

## Actual oracle sources and decoder checks

The existing 192-case native item oracle has 188 valid selections: 84 flat, 98 composite, four layered, and two armor, using 19 distinct large item template models. Its 388 selected layers comprise 318 actual resource-type-3 rasters, 60 type-2033 rasters, and ten type-6 PLT selections. These refer to 90 unique source names: 56 decode to RGBA8, 21 to DXT5, five to DXT1 RGB, and eight are PLT. All 90 installed bindings read and decode; all use KEY archive bindings in this mounted corpus, and none has a TXI sampler override. **309 of 388 selected layers use the original table fallback resource** because the requested primary is absent. The selection and source precedence must remain data driven.

`native_data/item_icon.gd` plans flat, three-part composite, palette layered, and armor icons from `baseitems`, `cloakmodel`, `iprp_spells`, `capart`, and `parts_robe`. Armor can omit hidden/missing parts and uses the default chest when all parts are absent. It applies per-part color overrides, then `asset_service.gd:icon_textures()` binds each selected source to `gui_replace01..NN`. PLT pixels use the original per-pixel layer/intensity indices, palette TGA rows, and special icon metal-channel selection in `palette_texture.gd`. The installed oracle contains eight reference PLT pixel hashes across layered/armor samples.

The existing `tests/native_inventory_test.gd` was rerun against `reports/native-item-icon-oracle-v1.json`: **610 plan, selection, fallback, and PLT checks passed; zero failures**. This verifies the covered data decisions and prepared PLT pixels. It does not prove live server overrides, small-icon attachment placement, GPU composition, or visual output parity.

## Evidence and open edges

- Full installed model geometry/UV/replacement census: `.cache/nwn84-icon-geometry-all.json`, produced by `.cache/nwn84_icon_geometry_all.gd`.
- Actual oracle source formats, palette names, binding classes, and fallback counts: `.cache/nwn84-icon-source-census.json`, produced by `.cache/nwn84_icon_source_census.gd`.
- Original selection/pixel oracle: `reports/native-item-icon-oracle-v1.json`; local rerun receipt: `.cache/nwn84/icon-planning-parity.json`.
- NWSync/HAK and server-specific `GUI_ICON` or icon source overrides were not mounted in this census. A production renderer must validate them at runtime and report missing resources explicitly.
- The four non-item special `gui_icon_*` models have separate animation/texture dependencies. They are outside the item-template count above.
