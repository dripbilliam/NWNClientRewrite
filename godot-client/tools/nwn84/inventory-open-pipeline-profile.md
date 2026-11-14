# Inventory open to visible item icons: offline profile

2026-11-14. This profile uses the installed original item assets, 24 distinct
items on two backpack pages, 1100 × 850 Forward+/Vulkan, VSync off, and a
separate process for each backend. It measures the completed frame containing
all 12 icons on each page. It does not include server delivery or a live Arelith
inventory. The same fixture and settings were used for both backends.

## Short closed-inventory warm period (500 ms)

| Stage after action | Retained original 3D GUI icons | Current bitmap icons |
| --- | ---: | ---: |
| First open: all icon resources prepared before click | Yes | No finished icon textures |
| First open: inventory controls committed | 13 ms | 237 ms |
| First open: icon models bound / bitmap icons ready | 18 ms | 227 ms last bitmap ready |
| First open: all 12 visible in a completed frame | **89 ms** | **274 ms** |
| First page-2 visit: all 12 visible | **33 ms** | **330 ms** |
| Revisited pages | 48 / 35 ms | 33 / 26 ms |

The retained backend prepared all 24 model/texture bundles while the panel was
closed. The current bitmap backend prepared some source assets, but still drew
each distinct icon through one private viewport and created a finished texture
on demand. Page 2 had no new asset completions after the tab click, yet its
last finished icon arrived 301 ms later. This isolates serial icon drawing as
the main first-visit cost in the current default. The measured readback itself
was small (22.6 ms over 26 icon callbacks in the full legacy capture); waiting
for one draw per icon accounted for most of the elapsed time. The new retained
backend avoids that per-icon draw, readback and reupload chain.

An unprofiled retained verification after removing the shortcut experiment
passed with 79 ms on first open and 75 ms on the first page-2 visit. The page
draw time varies between runs; the 33 ms page-2 value above is one profiled
sample, not a guaranteed latency. Prior unprofiled bitmap runs were about
276 ms and 322 ms for those actions.

## Immediately opened cold inventory (zero idle)

The retained backend started item requests within roughly 1–4 ms of the click.
In one frame-profiled run, the final bundle was delivered at 380 ms, controls
committed at 395 ms, models bound at 401 ms, and all icons appeared at 574 ms.
Another unprofiled cold run delivered the final bundle at 266 ms and showed
all icons at 541 ms. The worker's named icon raster preparation averaged about
10 ms per icon in that run; model decoding averaged less than 1 ms. The frame
profile also recorded 235 ms and 114 ms render-boundary intervals with only
about 3 ms of inventory callback work. The original inventory frame was not
layout-ready when controls committed, and the icon host reached 29 revisions
before its completed presentation. This fixture opens at the instant world data
is installed, so it includes first-use UI art, viewport and renderer setup.
Those render-boundary intervals are not attributed to icon selection or worker
CPU, and the fixture cannot prove their exact engine-internal cause.

## Shortcut experiment

Building retained inventory controls while the workers were still running
moved control creation from about 483 ms to 23 ms in a cold run. All icons
became visible at 581 ms versus 574 ms in the control run. The overlap did not
improve the user-visible result, so that staging code was removed. Item row
construction, signature calculation and request setup took under 2 ms in the
short-warm retained run. Optimizing those stages is unlikely to address the
first-visit delay.

## Next acceptance boundary

The retained backend is still explicit opt-in, and the current bitmap backend
remains default. The offline profile supports a live same-route inventory and
first-tab comparison before promoting the retained path. The native binary
builds a cached `CGuiIcon` Gob model and attaches it to the UI grid; exact
offscreen-page scheduling remains unresolved. See
[native inventory icon timing](native-inventory-icon-latency.md).

Local evidence: `.cache/nwn84-profile-frame-idle500-a.json`,
`.cache/nwn84-profile-frame-legacy-idle500-a.json`,
`.cache/nwn84-profile-frame-cold-a.json`, and
`.cache/nwn84-profile-overlap-cold-a.json`. Final unprofiled retained check:
`.cache/nwn84-retained-final-idle500.json`.
