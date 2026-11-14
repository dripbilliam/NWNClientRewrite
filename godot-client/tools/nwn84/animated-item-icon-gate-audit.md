# Animated item-icon template gate: bounded audit

`AssetService.gui-icon-v1` rejects a decoded model when `value.animations` is nonempty, before it prepares named replacement textures (`systems/native_data/asset_service.gd:193-195`). This is an explicit error, so the current path does not silently omit an animated model.

The installed NWN root plus `Prelude.nwm` census decoded all **372 native item templates** (`#x#L/LC`, `#x#R/S/RC/SC`, `ARMR#L/S`). None has a clip. See `icon-template-geometry.md` and ignored source report `.cache/nwn84-icon-geometry-all.json`. The separate `GUI_ICON_METAMAG` special model is animated but is not one of those item-template families. The 192-case item oracle exercises 188 valid normal item selections without encountering this gate.

The current retained item host uses `ModelInstance.install`, which installs source nodes and materials but does not evaluate a GUI animation clip. The existing bitmap GUI path has a separate `GuiPose`/actor route for animated general GUI models (`systems/native_item_icons.gd:146-185`). Simply removing the rejection would allow a potentially incorrect static pose. No installed native-valid item icon was found that this gate rejects, so `asset_service.gd` is unchanged.

**Open edge:** A live NWSync/HAK/override binding may replace a native item template with an animated model. This census did not mount those bindings, and the original client's exact animation choice for such an override has not been established. If one appears, capture its resource identity, model clips and native presentation before implementing an adapter. The current service will return the explicit animation error and prevent partial presentation.
