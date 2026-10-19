# Map artwork and pin presentation — 2026-10-16

Target: NWN:EE89.8193.37-17 x64, read-only
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No original binary/project changes or copied game assets. Installed resources
are resolved through the active module/HAK/KEY resolver. The UI fixture rewrites
an owned RAM buffer only; it never writes the installed module or templates.

## Executed original code

`scripts/inspect-native-map-presentation.py` records
`backups/animations/native-map-presentation-observations.json`.
`test/map-presentation-native.test.js` matches all740 observations:

- **660 complete pin-presentation executions**,140893860..140893ab9. Normal
  presentation reads position, converts coordinates with FLOAT*0.1 and signed
  CVTT, checks bounds and requires tile state EXACTLY1. Forced presentation
  bypasses this gate. Previous widget E8 controls attachment; the final E8 write
  occurs even on rejected pins and preserves a raw nonzero force value. The
  second position lookup, model/view lookup, FLOAT center/zoom arithmetic,
  biased CVTT pixel rounding, native WXYZ identity and return value all match.
  GUI attachment and virtual position/model/view transforms are explicit
  captured lower owners, not a port of the native GUI graph. The capture varies
  attachment's result and E8 mutation rather than silently assuming them.
- **32 bounded ImageMap2D executions**,1402c7580..1402c7615, with actual
  ReadINI1402cc370, CResRef construction/setter and17-byte copy18de80.
  Missing section/key clears the temporary string. Empty C strings select
  **MIDE01_A09**, the original fallback. Case, embedded NUL,16-byte truncation
  and Windows-1252 bytes are covered. This is the SET image branch, not the
  complete native file/INI parser.
- **48 bounded player-marker projections**,140894ba6..140894c74. It preserves
  fractional pixel coordinates, uses native FLOAT center/zoom arithmetic and
  clamps native Z to140e59494=-0.09000000357627869. It does not use pin rounding.
  Native following heading/model operations are outside this capture.

Successful logs: `map-presentation-native-capture-v2.txt` and
`map-presentation-native-tests-v3.txt`. Earlier failing drafts are retained but
are not evidence of parity. Constants were read from the verified executable.

## Static findings and graphics adapter

- Full constructor140891300 selects model index1 at1408914c4 and reads initial
  zoom16 from1412981e8. Model1 is **CTL_ICON_AREAMAP**; its installed mesh width
  is16 pixels at the existing GUI projection. The adjacent model-table DWORD
  is not a32-pixel mesh-width divisor. An initial guessed divisor was removed
  after native-constructor and installed-model inspection; final screenshots
  show adjacent tile artwork joining correctly.
- Refresh140893c70..140894717 reads the active map-image ResRef, replaces
  `gui_replace01`, and rotates the `icon` node by Tile_Orientation*90 degrees.
  CTL_MAP_PIN has up/down/disabled/hilite animations. Setup140893360 loads
  **CTL_MAP_XMARKER** for the player marker. These resources supply the actual
  geometry, UVs, textures and states; no substitute rectangles or walkmesh
  drawing are used. Model variants own their geometry/materials and preserve
  cached GUI templates. Textures remain shared under the existing asset owner.
- Widget getter140892300 calls GetMapPin1407daeb0 with reference/type. It reads
  the **first matching record**, including when duplicate references exist.
  Pin records remain separate client metadata; no registry IDs are allocated.
- Heading call140894c88 invokes14022f690..14022f6ce: zero XY returns0; otherwise
  atan2f(-X,Y)*FLOAT57.2957763671875. The adapter uses the existing native math
  helper after converting the canonical render orientation to NWN coordinates.
  The following Euler/quaternion renderer remains a graphics lower boundary.
- The mutable global FLOAT1412981c8 defaults to0.8 and is passed to1400a4c30.
  That wrapper tails to recursive1400a4b20, which writes node+0xa8. Its field
  semantics and complete native render consumption are not established here.
  It must not be called a geometric scale merely from the call-site argument.
  This property is not ported by this increment; authored model alpha is used.

Static capture provenance: `map-window-constructor-full-v1.txt`,
`map-panel-refresh-owner-v1.txt`, `map-window-virtual-owners-v1.txt`,
`map-pointer-position-owners-v1.txt`, `map-player-heading-range-v1.txt`,
`map-player-heading-angle-v1.txt`, `map-player-heading-constants-v1.txt`,
`map-model-scale-head-v1.txt`, `map-model-scale-tail-v1.txt` and verified data
captures. Failed no-unwind requests and runtime-launch attempts are not proof.

## Working local map UI

`MapUi` replaces the old normalized walkmesh overview. It resolves active SET
ImageMap2D names and orientations, renders installed tile skins at the verified
initial zoom, shows the player marker, and presents enabled notes through the
native pin helper. Note hover/press states keep the same DOM image so pointer
release can generate a click; clicking displays decoded note text. Model bounds
place images relative to their native root rather than guessed centers.

For single-player presentation, a separate view projects canonical PC128-byte
exploration bitmaps into0/1 tile states. It does **not** claim the actual client
exploration-message decoder or its other states. Changes are polled while the
panel is open. Area/character/assets changes invalidate the view, and errors
remain durable diagnostics. This local adapter is explicitly diagnosed.

Rendered gate: `scripts/smoke-live-map-ui.cjs`, final
`map-artwork-ui-v6.txt` / `live-map-ui.json`, **PASS**. Actual file selection,
character selection, M map key and right-click radial Use are exercised. The
RAM-authored NCS invokes ExploreAreaForPlayer and CreateObject243 with an active
UTW, followed by SetLocalObject/DestroyObject. The visible script-created note
has a type0 external wire reference; its bitmap, native position, click text
and same-reference area revisit pass. The3x3 starting room is already explored;
the12x12 second area proves mixed visible/hidden cells and its two initial notes.
Screenshots `live-map-ui.png` and `live-map-ui-other-area.png` were visually
inspected. Tests use the known fixture areas; product code has no module names.

Full **1,760 tests PASS** (`map-artwork-full-tests-v2.txt`), production build
PASS (`map-artwork-build-v5.txt`). Existing rendered casting and CreateObject
regressions PASS (`map-artwork-casting-ui-v1.txt`,
`map-artwork-create-object-ui-v1.txt`). Owned processes reached terminal exit0.
Earlier failed UI runs caught adapter/test assumptions and pin image replacement;
the final gate uses the corrected source. Some earlier Electron shutdown logs
contain a GPU teardown message; final map gate exits0 without that message.

## Still open / pause boundary

This completes the current **map artwork and pin-widget increment**, not all
map or spell systems. Native dynamic map-window/frame sizing, zoom/pan controls,
user-note creation/editing, Added/reference-number messages, GUI graph lifetime,
complete exploration/network transport and pixel-identical GPU output remain
open. The generic panel frame is retained; the incorrect fixed legacy map
background has been removed. Missing artwork/buffers/scene data are diagnosed.

The rendered revisit still encounters the previously unimplemented
DoSinglePlayerAutoSave engine call and missing `plc_w02.pwk`; these remain in the
runtime log and screenshot. They were not hidden or declared resolved. The
fixture's generic `creature died` feedback also remains outside this pass.

No new NWScript engine binding was added here. Last spell-impact audit remains
83 unbound commands /22 missing resources; spells, combat and campaign completion
are still open. The user requested a pause after this section. Seal a verified
checkpoint, then pause the persistent goal without beginning another section.
