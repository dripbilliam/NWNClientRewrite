# NWN-84 retained item-icon candidate, 2026-11-14

Status: **opt-in candidate, ticket remains In Progress**. `NWN_ITEM_ICON_BACKEND=retained` or Godot user argument `--item-icon-backend=retained` selects the retained implementation for every item-icon consumer. The default remains the complete prior bitmap implementation for one-step rollback. The retained selection does not instantiate `NativeItemIcons` or accept item-icon PNG messages in inventory, quickbar, barter, or examine.

The native chain is documented in [native-icon-flow.md](native-icon-flow.md), [native-icon-render-tail.md](native-icon-render-tail.md), and [native-icon-clipping-depth.md](native-icon-clipping-depth.md). The selected model is the original `GUI_ICON*` MDL, with original named replacement rasters/PLTs. `BASEITEMS.CanRotateIcon` chooses flat/composite small R versus S; layered uses R and armor S. Item models are retained in one live 3D host per active GUI panel. The Godot host uses a transparent `SubViewport`/camera bridge; the original draws GUI Gobs directly, so the host still needs full visual and performance acceptance. Non-item GUI art is outside this backend switch.

## Checks completed

| Check | Result | Local evidence |
| --- | --- | --- |
| Original installed icon oracle, normal/small and source refresh | 2,391 checks, 0 failures; original cases and override checks | `.cache/nwn84-service-w4-final.json` |
| Host isolated draw and compositing | 35/35 Forward+/Vulkan graphical, including first draw, live compositing and static draw scheduling | `.cache/nwn84-panel-host-batch-final.log` |
| Inventory installed models | 29/29 Forward+/Vulkan: first draw gate, page, drag model, close/reopen, UI scales and overlap, no item bitmap | `.cache/nwn84-retained-inventory-w4-final.json` |
| Barter installed models | Retained cold/warm/error graphical fixture and legacy control passed | `.cache/nwn84-retained-barter-gpu.log`, `.cache/nwn84-legacy-barter-gpu.log` |
| Quickbar and examine installed models | 19/19 Forward+/Vulkan: primary plus secondary quickbar models, normal and small examine model, draw receipts | `.cache/nwn84-quickbar-examine-batch-final.json`, screenshot beside it |
| Source parse | 12 changed production GDScript files passed pinned Godot `--check-only`; `git diff --check` passed | Local command receipts in this session |

The quickbar/examine headless fixture initially stalled before generic GUI frame art became ready. Its graphical run passed; the headless failure was not evidence of an item-service stall. The screenshot shows the wide examine icon near the lower-left icon hook. Its exact original-client placement remains to be compared.

## Isolated panel timing

Twelve distinct installed 1×1 items, 1100×850, Forward+/Vulkan, VSync off, separate processes, 300 completed-render intervals after 90 warmup intervals. This fixture has no game world or server. Source: `item_icon_panel_perf_pair.gd`.

| Backend/run | First panel admission | Mean completed-render interval | P95 |
| --- | ---: | ---: | ---: |
| Legacy A | 662 ms | 0.176 ms | 0.218 ms |
| Retained C | 524 ms | 0.249 ms | 0.303 ms |
| Legacy B | 680 ms | 0.190 ms | 0.237 ms |
| Retained D | 523 ms | 0.251 ms | 0.351 ms |

The retained candidate removes the old per-icon viewport capture, GPU-to-CPU readback, and `ImageTexture` reupload on misses. It admitted this isolated panel about 0.14–0.16 seconds sooner, while its live panel scene added about 0.06–0.07 ms to the sampled steady interval. These intervals must not be converted into a full-game FPS claim. Reports: `.cache/nwn84-panel-perf-{legacy-a,retained-c,legacy-b,retained-d}.json`.

These steady intervals predate the later `UPDATE_ONCE` panel change. Do not use them as the current steady cost.

## First icon visible after inventory open and page selection

The [offline latency report](inventory-first-icon-latency.md) measures the first completed graphical frame containing all 12 original icons on each page, after opening inventory and visiting the second page for the first time. With no closed-inventory idle time, the final four-worker retained candidate took 532 ms to show page 1 and 128 ms to show page 2, versus 792 ms and 331 ms on legacy. After 500 ms idle, candidate 87/42 ms versus legacy 276/322 ms. After 5 seconds idle, both had prepared all 24 icon sources; candidate 54/22 ms versus legacy 47/7 ms. These are isolated installed-content runs, not server or full-world results. The retained candidate now prepares its source bundles while inventory is closed, uses four asset workers, and batches a page's 3D host changes into one draw request. Backpack page changes reuse frame and equipment controls for both backends.

## Remaining acceptance

- A local-only full client with both backends reached its local server socket and then timed out in network admission before any area was entered. Both produced the same `await-admission: server-timeout`; reports are `reports/nwn84-{retained-local-d,legacy-local-e}.json`. An earlier sandboxed retained launch stopped even earlier because Windows-protected login storage was unavailable. Neither outcome measures icon parity.
- Compare native-binary and retained inventory, quickbar, barter, examine, drag and overlap at the user's actual display/UI scale on Arelith. Check first unseen item, page change, reconnect and server/NWSync override. The normal native item-icon use of `Gob::ReplaceTexture` is name-based; 50 installed composite templates author all three visible meshes as `gui_replace01`, and exact legacy replacement-state behavior for those exceptions remains a bounded visual edge. Do not assign layers by mesh ordinal.
- Installed 372 item templates have no animation clips. An animated server override remains unproven; the current `gui-icon-v1` worker reports an explicit error because the retained host has no icon-pose adapter. See [animated-item-icon-gate-audit.md](animated-item-icon-gate-audit.md).
- The [native inventory timing note](native-inventory-icon-latency.md) proves lazy Gob-model construction at grid refresh, but cannot establish when offscreen pages are populated. Closed-inventory bundle preparation is an optimization, not a verified native scheduling match. Keep that distinction in live review.
- Run matched live first-use and steady FPS/frametime tests only after Arelith visual parity. Pause other ticket work during FPS measurement. Keep the legacy default and NWN-84 In Progress until the agreed acceptance is complete.
