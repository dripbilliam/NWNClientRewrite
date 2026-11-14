# NWN-84 first visible inventory icon, offline comparison

This check measures the delay the player described: the interval from opening inventory or selecting a backpack page until the first **completed graphical frame containing every icon on that page**. The fixture also records the first icon, UI reveal and control creation; in these runs all page icons reached the visible frame together. It does not substitute `ui.visible` alone for icon pixels. The separate graphical fixtures verify that each backend's ready texture or retained 3D host actually contains nontransparent original icon pixels.

`inventory_first_icon_latency.gd` uses the installed original assets and 24 distinct icon source combinations: 12 one-cell icons on page 1, then 12 one-by-two icons on page 2. It opens page 1, visits page 2 for the first time, and revisits both. Each backend and idle period runs in a fresh process, 1100×850, Forward+/Vulkan, VSync off, no server or world. The closed-inventory idle period begins after the same item snapshot is supplied. Control reports are `.cache/nwn84-icon-latency-legacy-final-{0,500,5000}.json`; candidate reports are `.cache/nwn84-icon-latency-retained-w4-{0,500,5000}.json`. All six completed with visible pixels and no fixture failures. Values below are milliseconds for one matched run per row; they are directional, not a distribution or live Arelith acceptance.

| Closed idle | Backend | First inventory open | First page-2 visit | Return to page 1 | Return to page 2 | Bundles/images ready before open |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 0 ms | Legacy bitmap | 792 | 331 | 33 | 24 | 0 |
| 0 ms | Retained 3D | 532 | 128 | 29 | 40 | 0 |
| 500 ms | Legacy bitmap | 276 | 322 | 24 | 39 | 4/24, 20 pending |
| 500 ms | Retained 3D | 87 | 42 | 30 | 42 | 24/24 |
| 5,000 ms | Legacy bitmap | 47 | 7 | 8 | 8 | 24/24 |
| 5,000 ms | Retained 3D | 54 | 22 | 15 | 19 | 24/24 |

The retained backend now prepares the original model/texture bundles while the inventory is closed and the replicated items are known. It does not rasterize icon bitmaps during that work. Its scene host batches a page's model changes into one `UPDATE_ONCE` render request. Backpack page changes reuse stable equipment and frame controls. A separate two-to-four asset-worker probe gave an immediate-open/page-2 candidate result of 532/128 ms versus 547/187 ms with two workers; the 500 ms and 5,000 ms cases were effectively unchanged. The final candidate uses four workers. Source and graphical checks after that change passed: icon oracle 2,391 checks, inventory 29 checks, host 35 checks, quickbar/examine 19 checks, barter graphical cold/warm/overlap success, and legacy inventory 14 checks.

For this fixture the retained path materially improves cold and short-idle first use. Once all old bitmap icons have finished their closed-inventory preparation, the legacy path still reaches the first page-2 frame about 15 ms sooner. The retained view spends time rebuilding model instances and waiting for one additional 3D panel draw. Its repeat-page results also trail the legacy path. No change to the default backend is justified by these offline timings alone.

The [native inventory timing note](native-inventory-icon-latency.md) proves that grid refresh lazily builds and caches an icon Gob, but it cannot prove whether the native client populates offscreen pages before opening or on their first visit. Closed-inventory bundle preparation is therefore a measured latency optimization, not a verified scheduling match. The remaining acceptance is live Arelith item, tab, equipment, container, store, quickbar, examine and drag visual parity plus action-to-visible-icon timing at the user's actual display settings. The full local-only client reached its server socket but timed out in network admission identically with both backends, so it supplied no icon timing evidence.
