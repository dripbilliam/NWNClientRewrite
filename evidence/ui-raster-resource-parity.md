# UI raster and partial-block DDS repair, 2026-10-20

The previous UI path requested TGA before DDS, independently of the already
ported native catalog selection. An installed TGA could hide a selected server
DDS. Several flat UI consumers also treated CompressedTexture.image as raw
RGBA pixels. That object has dimensions but no decoded pixel array, so a valid
compressed portrait or icon could fail while its resource was present.
This before-state is source inspection, not a measured old-client screenshot.

The shared raster_texture loader now uses resolveTextureResource and the active
resolver's native format/table precedence. NativeUiAssets separates texture()
for rendering models from image() for flat decoded pixels. Portraits, character
records, both quickbars, action-queue icons and radial icons use the latter
conversion. Pixel caches belong to the current asset owner. Singleplayer
quickbar completion also checks that its asset owner has not changed. The
creator retains its resolver across asynchronous size attempts.

The base lobby now has a bounded, trusted-frame texture-read IPC endpoint.
It uses the window's installed UI resolver. The selected-character screen uses
its captured session ID and that session's texture endpoint instead. These are
resource reads; no character, packet codec, gameplay rule or canonical world
object is changed. No server-specific spell, portrait, creature or resource
name is added to production behavior.

The pinned original target is NWN:EE89.8193.37-17 x64 nwmain.exe, SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
REA/Ghidra analysis and Unicorn use it read-only. Portrait84c2f0..84c54a calls
84c1b0..84c2e7 to try size1..5 in0,+1,-1,+2,-2,+3,-3,+4,-4 order. Size0 returns
the raw ref. Sized existence checks ask for TGA3 then DDS2033. Native uppercase
suffix literals and the replacement's lowercase names are equivalent resource
keys. The old network helper omitted the±4 endpoints and tried raw size0 in a
sized lookup. The shared portrait_resource helper corrects those boundaries;
creator medium ordering remains native.6,144 original-instruction mask cases
agree on candidate/admission order and result. Allocation/string/resource
helpers are captured boundaries; this is not original GUI execution.

Native portrait widget84c550 replaces gui_replace01 and marks its texture scope
as portraits. Native6fb560 calls the size resolver and assigns the result to
that widget. The existing native image wrapper0e5c60 and compressed-selection
0f56c0 evidence establish the common image format selection. The complete
virtual GUI-to-GL call chain has not been executed by this fixture.

Actual cached-resource validation then found c_a_chicken DDS209x273. The old
BioWare parser rejected any non-power-of-two dimensions and checked the top
size using width*height/2, omitting partial edge blocks. Original CResDDS
OnResourceServiced0f9d10 accepts the legacy20-byte or standard128-byte header;
GetDDSAttrib0f9b90 retains legacy dimensions and exposes standard DXT1/DXT5
block-size arithmetic.192 unchanged-instruction header cases cover powers of
two, small images and arbitrary dimensions. No pixel decoding or original GL
draw occurs in that oracle.

The repaired parser retains bounded positive dimensions and validates complete
4x4 edge blocks. For209x273 DXT1 the actual top payload is29256 bytes, with nine
mip levels in the38836-byte cached file. Its SHA256 is
4ed07661e0f06f3ada96d4ed13d1e917602a90c060ec6363bf8a4a20f87be2d9.
The header probe writes metadata/hashes only. Relaxing dimensions alone first
produced a blank GPU readback, so it was not accepted as the complete fix.

[WebGL S3TC](https://registry.khronos.org/webgl/extensions/WEBGL_compressed_texture_s3tc/)
has block-alignment upload restrictions. Generic s3tc_decode implements the
[Khronos block equations](https://registry.khronos.org/OpenGL/extensions/EXT/EXT_texture_compression_s3tc.txt)
for RGB/RGBA DXT1, DXT3 and DXT5. Incompatible base dimensions become RGBA
DataTextures with unchanged dimensions and authored mip levels. Aligned world
textures retain their compressed GPU path. Flat S3TC UI pixels decode directly,
avoiding GPU-context allocation/readback for each icon. DDS lower-left rows are
converted for top-left ImageData; TGA orientation is preserved. Other supported
compressed UI formats retain an explicit straight-alpha GPU conversion.

Color interpolation mixes normalized565 endpoints before rounding output
bytes, consistent with the equations and Microsoft's
[DirectXTex Decode565 implementation](https://raw.githubusercontent.com/microsoft/DirectXTex/main/DirectXTex/BC.cpp).
Tests cover both DXT1 palettes, opaque RGB versus transparent RGBA black, DXT3
alpha nibbles, both DXT5 alpha tables and high/cross-byte selectors, partial edge
blocks, preserved mips and selected-source failures. These are specified codec
operations, not inferred replacements for missing server assets.

The64-block/1024-pixel GPU comparison validates510 RGB endpoints within one byte
and578 alpha endpoints exactly on the observed NVIDIA5070Ti/ANGLE D3D11 path.
Interpolated entries differ by the separately recorded small values; exact
GPU/native interpolation is not claimed. Production follows the specification
equations and is not tuned to the observed driver's results. The earlier
all-pixel strict-comparison failures remain in v7..v11 reports. Canvas origin
and premultiplication affected the first comparisons; final endpoint comparison
uses straight-alpha raw framebuffer pixels. This evidence does not turn that
limited comparison into whole-native-renderer parity.

Final Chromium ui-raster-v15 passes eight functional cases: selected DDS/KTX/TGA
colors in flat/network UI, tiny-to-huge portrait fallback, separate owners,
selected-source failure, multiplayer/singleplayer quickbar DDS images, and an
owner change during an asynchronous singleplayer icon load. Five actual cached
or installed images decode to nonblank pixels, including209x273 RGBA. The
production main-module model probev3 loads its texture with nine mips and draws
an idle diagnostic pose with no GL error. The screenshot is texture-upload
evidence, not acceptance of the entire creature's geometry/material appearance.
Its fxpa_feather warnings remain recorded.

Full creator-v18 passes the15-step workflow, custom resources, preserved scroll,
feat filtering/groups, voice decode/play/disposal and both human/half-orc
previews. Lifecycle-v5 passes19 owner/race cases. Inventory-v2 retains seven
icons, default14 slots, the Options-only creature-slot setting and unchanged
canonical items. The installed HUD replay and built singleplayer quickbar
assignment/radial/modifier/activation/reload checks pass.76 focused Node checks
pass. Final build is index-Bv-y_20u.js.

Packaged main-menu-v4 actually opens the menu and exercises production preload
and trusted IPC. It selects gui_char_icons DDS, preserves a typed resource miss,
rejects an invalid ref, and makes no game join or Node/content fetch. Its
stylesheet's Google Fonts request is cancelled before sending by the fixture;
this is recorded rather than described as zero browser requests. The initial
v1 main-menu fixture waited without opening the menu and is rejected.

A short cached dense recheck retains ten programs through120 orbit frames.
It supplements the earlier two-minute observation; it is not a new causal
speedup claim or animated crowd/particle/fullscreen acceptance. The current
local gameplay client48208 and server20964 are untouched. All new resource
checks forbid downloads and use only previously cached data and the install.
Original binaries/installation are not modified and no asset bytes are copied.

The goal remains active.33 selectable portrait rows still lack source images
in the selected collection and supplied portrait folder; the install root has
no portraits directory. fxpa_cloud02 and fxpa_feather source/particle gaps,
physical-key feedback and broader live density/performance acceptance remain
open. These are not concealed by the image decoder. The assertion-checked
creation-experience-ui-raster-proof-v1.json hashes the current sources and
retains the verification scopes and limitations.


2026-10-20 follow-up: installed data/prt lookup and native portrait priorities now recover six rows; coverage329/356,27 still missing in inspected contexts. Creator-v19/lifecycle-v6 and new built main-v5 index-DR_H7-HZ.js pass. Current raster-proof-v2 and current-audit-v4 supersede earlier counts/build, retaining earlier codec/GPU/model limitations. See installed-portrait-directories.md.
