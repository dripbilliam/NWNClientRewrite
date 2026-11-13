# NWN-75 original Nui JSON draw-list item gates

Original installed `nwmain.exe`, SHA-256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`; image virtual addresses. This continues the [draw-list callback](nui-json-draw-list-callback.md). It describes static branch choices, not the number of items or windows active in a frame.

## Item construction and ownership

`Nui::JSON::LayoutableJ::Construct` `0x140741070` reads the optional `draw_list` key through `0x14071ca60`. If present, that helper requires a JSON array, walks its elements through `0x140729810`, and parses each element with `0x14075dda0` into a `0x3d8`-byte item. The factory separately reads `draw_list_scissor`, partitions parsed items by `item+0x4` (`order == -1` versus other values), calls `0x140748b80` once per partition at `0x140745697` and `0x1407456fa`, and conditionally installs the resulting callbacks at output offsets `+0x688` and `+0x6a0`. The callback table and wrapper route to `0x14073b700` as documented in the prior supplement. `draw_list_scissor` configures that path; `draw_list` supplies its actual items. Factory REA `ev_22c002c865997b52b6d2cdaa9b9b1462dd7d9fff367c19b2df563ac41a6bc4b0`; array helper `ev_4acbafc7de20beb41894219f17984e2488489bf7428ffc896cb2e12ebb113fc6`; iterator `ev_673694150c2382ff81cc7e4e3d3c71f4b5a90175632d1dbcad3f581eb2cacf0f`.

Parser `0x14075dda0` stores numeric `type` at item `+0x0`, optional `order` at `+0x4` and optional `render` at `+0x8`. It parses `enabled`, `color`, `fill`, `line_thickness`, and optional `arrayBinds` before type-specific fields. An out-of-range type takes an `unknown draw_list_item type` error path. The parsed fields and their renderer targets are:

| JSON `type` | Type-specific keys | Conditional numeric command kind from `0x14073b700` |
| --- | --- | --- |
| 0 | `points` | 14 filled or 15 stroked |
| 1 | `a`, `b`, `ctrl0`, `ctrl1` | 3 curve |
| 2 | `rect` | 7 outlined or 8 filled ellipse/arc |
| 3 | `c`, `radius`, `amin`, `amax` | 9 outlined or 10 filled arc |
| 4 | `text`, optional `font`, `rect` | 16 text |
| 5 | `image`, `rect`, `image_aspect`, `image_halign`, `image_valign`, optional `image_region` | 17 image; also calls shared image/WebM updater `0x140a93db0` |
| 6 | `a`, `b` | 2 line |
| 7 | `rect` | 4 outlined or 5 filled rect |

The parser is `ev_27b803c4913d2a86cde77c487e460338e5727bfaf554862a1218d1670d090f7c`; the renderer body is `ev_f78bc91354619d845d659aecea8d68ce1b9cec938826e419dc9cc9aee55cefb8`. Each exact producer callsite and kind is in [nui-json-draw-list-ledger.json](nui-json-draw-list-ledger.json). `fill` is dynamically resolved, so the paired outlined/filled kinds are alternatives. Text and image values are also dynamically resolved.

## Invocation and render-mode gates

The callback iterates the installed item vector in `0x3d8` strides. It first resolves the dynamic `enabled` value at item `+0x28`; a false value skips the item. It then reads `render` at item `+0x8`, the callback state byte at `param_4+1`, and for some modes flags in the current context. The exact static branch choices are:

| `render` value | Condition required to reach this item's command producer |
| --- | --- |
| 0 | Always, after `enabled` |
| 1 | `*(byte *)(param_4+1) == 0` |
| 2 | `*(byte *)(param_4+1) != 0` |
| 3 | State byte nonzero and context `+0x10c` nonzero |
| 4 | State byte nonzero and context `+0x12c` nonzero |
| 5 | State byte nonzero and context `+0x11c` nonzero |
| Other | Falls through to the item command producer |

`+0x12c` is decimal 300 in the decompiler. The byte and context fields have no established semantic names, so this table records only the original conditions. After these gates, the type and dynamic geometry/color/image fields choose the command producer. The producer writes to the Nuklear command list; `0x140a7c340` converts nonempty commands to CPU geometry, and `0x140a71760` conditionally reaches imported `glDrawElements` for the resulting indexed geometry. Converter REA `ev_ad209304a0b1e3d9ce73250523f0be0b533a57ffa37433b89d53a3d9236ce940`; draw REA `ev_6b5e1be5df3d0ec1c19e05d9f5114d2a9453a5c0bd89c9f09f1a3012d4826278`.

The exact JSON assets loaded, item count, runtime values of `enabled`/`render` and active window visibility remain unresolved. A static command alternative does not imply a per-frame command or GL draw.
