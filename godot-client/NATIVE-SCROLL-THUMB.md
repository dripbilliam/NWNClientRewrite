# Content-sized original scrollbar thumbs — partial parity

The shared `native_scrollbar.gd` now sizes its thumb from visible content rather
than always drawing a20-pixel thumb. `native_data/gui_scroll_range.gd` implements
original `CGuiSlider::SetScrollRange`1401e7950 and
`SetScrollRangeVisible`1401e7990: range clamps to at least1; the visible ratio is
`visible/(visible+range-1)`; pixel height rounds like the original float
instructions; `thumbsize` time is `(pixels-3)/30`, with its authored3.01-pixel
minimum. Original float32 results are retained.

The image renders original animated vertices and UVs. Finished screenshots/end
caps are never stretched. Changed content requests a new original pose through
the native cache. Current image/geometry remain until the newest pose publishes;
stale completions cannot overwrite it. Ordinary scrolling only repositions the
thumb: it does not render another model or send gameplay requests. Short content
fills the original rail; long content gets a smaller proportional thumb.

Godot exposes a maximum position, while the original slider stores a range one
beyond its last position. That adapter conversion is explicit. Exact original
edit/list content/page coordinate mapping remains open; this milestone does not
accept every text viewport's extent as identical to the original.

Skills/Feats lists now use their linked36-pixel row step for arrows and wheel;
their description editor retains Galahad's17-pixel font line step. Original
`CGuiButtonListbox::Update`1401f0600 measures `next`/`root` row hooks into the
scrollbar step field. Wheel handler1401eec50 delegates to the shared three-step
rule. Actual native row input verifies wheel108 and arrow36 independently of
font height.

## Evidence and accepted scope

Root `backups/animations/rea-native-scroll-thumb-v1.json` retains original
slider/list code. `scripts/inspect-native-scroll-thumb.py` executes original
range/visible instructions unchanged offline; only animation publication and
scroll-position callbacks are captured. Its72 cases cover empty/no-overflow,
range clamping, varied page/rail lengths, rounding and minimum thumb size.
Native results match the original float32 bits.

Final unchanged-source, clean debugger receipts:

| Run | Checks | Scope |
| --- | ---: | --- |
| `native-scroll-thumb-range-final-v1` |73| All72 original-instruction cases |
| `native-scroll-thumb-frame-v2` |32| Record, populated-row wheel/arrows, dynamic thumb, dragging/placement and typed actions |
| `native-scroll-thumb-examine-final-v1` |62| Arrow/held/page/thumb/wheel input, content changes,125% scale and Identify routing |
| `native-scroll-thumb-store-final-v1` |32| Merchant and confirmation UI |
| `native-scroll-thumb-barter-final-v1` |31| Original barter UI and amounts |
| `native-scroll-thumb-pose-final-v1` |69| Original animated vertex/UV/cap geometry |
| `native-scroll-thumb-retirement-final-v1` |13| In-flight native GUI render teardown |
| `native-scroll-thumb-playability-final-v1` |1314| Existing headless regression aggregation |
| `native-scroll-thumb-actions-final-v1` |99| Original-server authoritative localhost5125 regression |

The server run exited0, retained no workers and made zero public connections.
Long Examine content rendered a68-pixel thumb,85 pixels at125% scale, with
17-pixel line input. Reverting to short content filled the rail. Fixed20-pixel
test expectations were replaced by ratio geometry checks backed by the separate
original-instruction oracle.

Early retained failures were a reserved test-class identifier and comparing
JSON-decoded float64 decimals before narrowing to their original float32 bits.
Only final receipts support acceptance. The prior intermittent blood-model
viewport assertion remains a separate open limitation.

Full scrollbar/UI parity remains false: finish exact text/list page extents and
partial lines, live resize geometry, all visual/audio states, pixel-scroll modes,
alternate layouts/fonts/locales/scales and original-client input/visual
comparison. The wider UI goal remains active; general porting stays deferred.
