# Original GUI model texture sampling

The [animated GUI sampler follow-up](NATIVE-GUI-ACTOR-SAMPLER.md) fixes a
remaining integration gap: animated actors lacked the static Part identity
used to select the original per-bitmap sampler. This was still repeating tab
borders despite correct worker metadata. The new actual-renderer test covers
that path; the earlier isolated sampler/worker tests did not prove it.

The chooser's gray panel bands and repeated tab borders exposed a shared GUI
renderer error: private native GUI-model viewports forced linear filtering and
repeat for every bitmap. Installed `gui_boxes_ingame.txi` specifies filter0,
mipmap0; `gui_pre_playtabs.txi` and `gui_ig_chartabs2.txi` also specify clamp3.
The replacement was blending the atlas's narrow stripes and repeating its
out-of-range tab UVs. Using the active catalog's original flags removes the gray
bands in the reviewed chooser; complete original pixel/pose comparison remains
unfinished.

Original binary evidence is retained in
`../backups/animations/rea-native-gui-sampler-v1.json`:

- CAurTextureBasic constructor0e4d60 defaults clamp0, mipmap1 and filter1.
- Init0ebe40 obtains the active `.txi` and parses each line. ParseField0ecf20
  matches names case-insensitively. Bool Parse0a0c00 accepts true/false/1/0;
  other tokens retain the preceding value. Short Parse0a0250 supplies clamp.
- GetClamp0eb700, GetFilter0eb820 and GetMipMap0eba00 read those fields.
- GLRender::SetTextureParameters0b8100 uses clamp bits1/2 independently for S/T,
  GL_CLAMP_TO_EDGE or repeat. Magnification follows filter. Without mipmaps,
  minification remains nearest even when magnification is linear. With mipmaps,
  it chooses nearest-mipmap-nearest or linear-mipmap-linear.

`scripts/inspect-native-gui-sampler.py` executes those original sampler and TXI
dispatch/parse instructions in the owned CPU emulator.64 GL sampler cases and41
TXI field sequences are retained in
`../backups/animations/native-gui-sampler-observations-v1.json`. OpenGL
publication, C parsing/comparison, unrelated font parsing and stack-cookie
checking are explicit captured boundaries; this is not an original GPU oracle.
`reports/native-lobby-art-source-v2.json` and its raster images retain the actual
installed MDL/bitmap/TXI identities. Tab mesh/UV animation evidence is separately
retained in `native-gui-sampler-tabs-animation-v1.json`.

Native GUI worker requests now opt into `gui_texture_info` with an explicit
processor version. The worker records present/absent TXI lookups and byte hashes
through the existing tracked catalog reader. GUI model bundles carry per-source
bitmap sampling metadata and mip counts, including actual texture replacements
and item-icon layers. Ordinary world model preparation is unchanged. Persistent
prework validates these dependencies, and changed processor/options identities
prevent older finished GUI images from bypassing the correction.

Private GUI model rendering applies metadata by physical source mesh/bitmap
identity, not GPU texture-object identity: identical raster bytes with different
resource names may have different TXIs. Actor reuse identity includes the sampler
metadata. Standard materials handle matching S/T clamp/filter cases. A private
unshaded GUI shader supplies independent clamp axes and the original asymmetric
min/mag case; texel addressing preserves edge taps, bilinear interpolation and
the selected mip level. It does not change world lighting or materials.

Current verification:

- `native-gui-sampler-pixels-v3`:126 checks, including all105 original
  instruction observations and20 actual native edge/minification/mip pixel cases.
- `native-gui-sampler-prework-v4`:34 actual worker/cache checks: missing, added,
  changed and removed TXI; fresh-catalog warm reuse; higher-priority overrides;
  unchanged raster/model inputs and world-policy isolation.
- `native-gui-sampler-chooser-v2`:25 source chooser/input checks and reviewed
  native screenshot. `native-gui-sampler-pages-v1`:32 roster/source-page checks.
  `native-gui-sampler-phase-v1`:22 presentation/input/lifetime checks.
- Startup and the real owned local-server action suite have separate receipts.
  The scoped acceptance audit pins their current sources and the rollback.

Retained failures: pixels-v1 caught the original's asymmetric min/mag policy;
the implementation was corrected and pixels-v2/v3 pass. Reuse-v1 supplied the
wrong argument to the existing sealed-corpus test. Reuse-v2/v3 tried installed
models with animated mesh UVs, which deliberately use the transient GUI pose
adapter, so its actor-cache assumptions failed. Those attempted test changes
were reverted. Reuse-v4/v5 use the existing sealed corpus, whose manifest lists
TXIs but omits their recorded bytes (`pnl_party_bar:2022` is the first refusal).
The test now records dependency diagnostics and drains safely after a missing
actor; assertions remain in place. This old-corpus regression is **not accepted**
and is excluded from passing totals. Its dependency closure must be recaptured
or independently proven; no installed/public-resource fallback was added.

Still required: original-game GPU/state/scale/role comparison, anisotropic mip
filtering, other TXI effects, and direct canvas bitmap/font sampling outside
the GUI-model viewport. Chooser tab/record artwork poses/proportions, complete
record/local BIC/editing/keyboard behavior and the entire remaining UI inventory
are open. The earlier intermittent blood-pixel failure and pending-wind warning
remain open. No FPS, complete GUI sampling, full UI parity or goal-completion
claim follows from this milestone; general porting stays deferred.
