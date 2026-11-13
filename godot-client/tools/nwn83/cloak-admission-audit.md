# NWN-83 worn-cloak admission checkpoint

The creature path omits equipped cloaks. `systems/native_data/creature_appearance.gd:75-76` reads slot 64 and `cloakmodel.2da` only for HIDEWING/HIDETAIL. `systems/native_render/creature_stream.gd:147-158` emits right/left weapons and helmets, never slot 64. The actor installer receives no worn-cloak piece.

`systems/native_data/item_appearance.gd:33` selects `gi_cloak01` for base item 80 in the generic item plan. That does not prove the worn model, skin, animation or material mapping. Captured `cloakmodel.2da` has separate MODEL, TEXTURE and HIDE columns. Native worn-model naming, body-type attachment and resource precedence still require an original-asset oracle.

No production source changed. A safe fix needs original behavior and graphical animation, color, equipment, lifecycle and body-type checks. This exceeds a bounded small fix; NWN-83 remains open.
