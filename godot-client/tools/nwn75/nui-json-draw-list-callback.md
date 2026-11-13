# Original JSON draw-list callback branch

Scope: installed `nwmain.exe` SHA-256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`. This maps a high-fanout Nui callback from JSON layout construction to numeric command producers and their already mapped GL draw boundary. Static dispatch and JSON data choices do not establish that a corresponding window is open in a given frame.

`Nui::JSON::LayoutableJ::Construct` `0x140741070` parses `draw_list_scissor` and calls helper `0x140748b80` twice, at `0x140745697` and `0x1407456fa`, storing returned/derived state through offsets `+0x688` and `+0x6a0` in the output object. In `0x140748b80`, a RIP-relative `lea` at `0x14074a3c2` loads `std::_Func_impl_no_alloc` callback vtable `0x140e3b6e0` for a `Nui::Layout::Layoutable`/`WidgetRenderState` lambda; the helper retains it in a layout wrapper. The two small helpers `0x140750840` and `0x140757bf0` copy/move the same callback type. REA factory retained `ev_22c002c865997b52b6d2cdaa9b9b1462dd7d9fff367c19b2df563ac41a6bc4b0`, helper retained `ev_d304761906f7bab776ce3845cebd0a68e0387a38bab9bec72ef20278f8ad712e`, pinned LEA `ev_8d3044f66f3e4744d2d9ea53f2537cddf8c10f28e2187b83b8bd8e4f659c9ff7`, copy `ev_3da66ee2390819bb8c2cc87623151dc1205f391ef23cc22609d2caab20f72089`, move `ev_0ffbfdfc55947ff1e5cf0e576826b8e45d8c4549537e10fdad92458d26e23c06`.

The callback table's virtual `+0x10` points to `0x140754b70`; that thin wrapper copies its `WidgetRenderState` arguments and calls `0x14073b700` at `0x140754b94` (REA callback incoming `ev_7443ed323a2f22a1ac027e131f9014870d143cdb6c7632f9708f715463106120`, wrapper `ev_6eaea072f2d1dbdb365b41fc693a161c468254505a6357c683228bcac70722f4`). `0x14073b700` reads a data-selected draw-list item family and dynamic values. Its direct callsites include these numeric command producers:

| Numeric kind | Producer | Exact callsite |
| --- | --- | --- |
| 2 | `0x140a8be00` | `0x14073c42d` |
| 3 | `0x140a8bd10` | `0x14073c866` |
| 4 | `0x140a8c120` | `0x14073ca5f` |
| 5 | `0x140a82050` | `0x14073c9a6` |
| 7 | `0x140a8bbf0` | `0x14073cc62` |
| 8 | `0x140a81e20` | `0x14073cb93`, `0x14073cbae` |
| 9 | `0x140a8bb30` | `0x14073d10c` |
| 10 | `0x140a81d80` | `0x14073ceaf` |
| 14 | `0x140a81f20` | `0x14073c0b3` |
| 15 | `0x140a8bfe0` | `0x14073c147` |
| 16 | `0x140a81600` | `0x14073d305` |
| 17 | `0x140a7db90` | `0x14073d6df` |

These 13 callsites span 12 distinct numeric kinds. They are recorded with per-producer REA evidence in [nuklear-producer-incoming.json](nuklear-producer-incoming.json); the `0x14073b700` retained body is `ev_f78bc91354619d845d659aecea8d68ce1b9cec938826e419dc9cc9aee55cefb8`. The callback's image branch at `0x14073d5ed` calls shared image-descriptor updater `0x140a93db0`, which can decode/upload WebM texture or select loading/error fallbacks; see [image/WebM updater](nui-image-webm-updater.md). Item kind, dynamic color/geometry/texture values and clip state select which producer executes. The complete original JSON item schema and active item set are still open.

The producer callsites reach the command allocator/linked list, then `0x140a7c340` converts each numeric case to path, glyph or textured-quad CPU geometry. `0x140a71760` maps UI vertex/index buffers, invokes that converter and draws nonempty command geometry through imported `glDrawElements` (REA converter `ev_ad209304a0b1e3d9ce73250523f0be0b533a57ffa37433b89d53a3d9236ce940`, UI GL draw `ev_6b5e1be5df3d0ec1c19e05d9f5114d2a9453a5c0bd89c9f09f1a3012d4826278`). The case-by-case geometry and clipping gates are in [Nuklear command conversion](nuklear-command-conversion.md). This is a conditional CPU/GL leaf, not twelve draws per frame.

Remaining: determine which JSON windows install the two draw-list branches, whether they publish/open in the weak registry, and which data-selected item kinds and asset names appear at runtime. The static factory/callback and command-producer census cannot prove active frequency.
