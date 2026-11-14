# Retained item icon colour and orientation correction

2026-11-14. A live Arelith report showed inventory icons that were dark,
apparently transparent and upside down with the opt-in retained backend.
The current bitmap backend remains the default.

## Causes and change

- `NativeItemIconPanelHost.bind_slot` kept each textured MDL part's diffuse RGB.
  The current bitmap viewport neutralizes RGB to white while retaining alpha
  before applying the original GUI replacement raster. The retained host now
  applies the same material rule. Untextured parts keep their authored colour.
- The retained host flipped the entire final viewport texture vertically.
  A paired original-content capture showed all twelve page-2 icon silhouettes
  reversed against the bitmap backend. The host now uses the camera's normal
  image orientation and maps each slot anchor to the equivalent unflipped
  viewport position. It recalculates positions on panel resize.

The correction is in the one retained panel host used by inventory, barter,
quickbar, examine and drag previews. It does not mix the bitmap item backend
into retained mode.

## Verification

- Panel host headless 21/21 and graphical 35/35: slot ownership, alpha,
  screen projection, resize, settled draw and reuse.
- Original inventory graphical 29/29 at 3440 width and UI scales 1.0, 1.3,
  1.9; overlap and drag preview checks included.
- Original barter graphical: cold presentation, placement at three scales,
  overlap, drag preview and reopen passed.
- Original quickbar and examine graphical 19/19.
- Offline 24-item inventory capture after the correction shows twelve visible
  screen icons on both first-open and first-page-2 snapshots. The paired
  bitmap screenshots show the same upright icon silhouettes and similar
  colours. The diagnostic capture now checks actual parent-window pixels, so
  a finished 3D viewport with a blank UI frame fails.

These are local installed-content checks, not live Arelith acceptance or an
exact per-pixel colour proof for every NWSync/HAK icon. The running client
must be restarted to load the updated GDScript before the user checks it.

Local captures and reports are in `.cache/nwn84-color-retained-screen-c*`,
`.cache/nwn84-color-legacy-a*`, `.cache/nwn84-retained-visual-fixed-b.json`,
`.cache/nwn84-barter-visual-fixed-c.json`, and
`.cache/nwn84-quickbar-examine-fixed-a.json`.
