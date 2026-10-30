# Original bitmap fonts — scoped native implementation

The framed inventory, container, equipment AC, gold amount, barter, merchant
confirmation and Examine/Identify controls now request their original caption
font and color from the active GUI resource. They share a bounded native font
owner. Existing generic controls outside these frames are not converted by this
checkpoint. The full UI goal and `full_font_parity` remain incomplete.

`systems/native_data/bitmap_font.gd` parses original TXI glyph metrics;
`systems/native_bitmap_fonts.gd` prepares original raster data through native
workers and publishes Godot FontFile glyph caches on the main thread. There is
no JS rendering or runtime font dependency. The offline JS oracle is test-only.

## Original rules and implementation

- `CAurFont::CAurFont` at `14004b4d0` requests an ordinary texture reference.
  Bitmap fonts retain the active catalog's raster selection rules, including
  DDS rather than TGA where selected. Do not force a local installed TGA over
  a selected server resource. Legacy CResFNT is a separate original path.
- `CAurFont::TextOut` at `14004c870` uses glyph U bounds, texture width, fixed
  line height, baseline and spacing. The visible-string measurement routine at
  `14004c120` rounds the cursor after glyph advances. The installed Galahad14
  resource actually has a17-pixel line height and14-pixel baseline; digits in
  its name are not the rendered font height.
- Original byte glyphs map to the existing CP1252 Unicode text projection,
  including Euro and punctuation. Short atlases retain glyph-zero fallback.
  Original server RGB spans still override the caption's default text color.
- Original explicit TTF names use `ttf <resref> <pixels>`, as recovered from
  `CAurTextureBasic::ParseTTFTokens` at `1400ed500`. Resource and requested size
  are supported; the original STB raster/contrast/outline path is not accepted
  as identical to Godot's TTF rendering.
- Bitmap FontFile configuration disables system fallback, mipmaps, MSDF,
  antialiasing, subpixel positioning and hinting. Glyph publication uses the
  source atlas with its original metrics. Native controls use nearest filtering
  and avoid adding a second outline/shadow over the authored glyphs. Switching
  away restores the control's prior filter and effects.
- Weak bindings discard retired controls; a late old request cannot overwrite
  a newly selected font. Unavailable resources report failure, and close drains
  pending native work. No cache purge or game texture decoder change was needed.

Static original evidence: `../backups/animations/rea-native-bitmap-font-v1.json`
and the preceding `rea-native-legacy-font-v1.json`. These are decompilation
observations, not live original-client visual acceptance.

FontFile API/settings were checked against the [official bitmap-font importer](https://raw.githubusercontent.com/godotengine/godot/master/editor/import/resource_importer_imagefont.cpp)
and [FontFile documentation](https://docs.godotengine.org/en/latest/classes/class_fontfile.html).

## Verification and limits

Final source-pinned debugger receipts, all exit0 with no engine/lifetime error:

| Receipt prefix `native-font-` | Checks |
| --- | ---: |
| `bitmap-checkpoint-v2` |109 |
| `examine-checkpoint-v1` |46 |
| `inventory-checkpoint-v1` |160 |
| `store-checkpoint-v1` |32 |
| `barter-checkpoint-v1` |31 |
| `retirement-checkpoint-v1` |13 |
| `text-checkpoint-v1` |1025 |
| `playability-checkpoint-v1` |1314 |

`native-font-actions-checkpoint-v1` passed99 checks against the isolated
original server on `127.0.0.1:5125`, including real Lore/paid Identify and
inventory/merchant actions. Native exit0, zero remaining workers, no public
connections. The live inventory reports original Galahad loaded without font
failures or pending bindings. Existing servers and user clients were preserved.

`native-bitmap-font-oracle-v5.json` records independent original TXI metrics,
selected raster source hashes, DDS top-mip hashes and22 TGA glyph-region hashes.
It stores no original pixels. Native tests verify TGA decoder agreement,
compressed block preservation, source selection and FontFile publication against
fresh native decompression. **DDS byte-level GPU interpolation parity with the
original executable is not established by this test.** Full original-client
screenshots, TTF raster parity, double-byte fonts, arbitrary server font variants,
nonzero spacing and all caption states/scales remain open.

Early atlas assertions incorrectly compared a selected DDS with an available
TGA. Independent decoders and source hashes identified that test assumption.
Subsequent integer-DDS reference experiments did not match Godot's decompression
exactly and were discarded; those failed receipts are retained, not acceptance.
One font run was mistakenly invoked headless and awaited a graphical frame;
only that owned test was stopped, then the graphical rerun passed.

The earlier intermittent blood screenshot failure documented in
[NATIVE-SCROLLBAR.md](NATIVE-SCROLLBAR.md) remains open despite this passing
local action run. No particle/combat change was made in this font work.

Examine body formatting and remaining scrollbar input/state rules are next.
The generic field-by-field item description is still visibly unlike the
original. This checkpoint does not accept any entire screen as100% complete.

Rollback: `backups/native-bitmap-font-v1.zip`. Reproducible scoped audit:
`node godot-client/tools/audit-native-bitmap-font.mjs`.
