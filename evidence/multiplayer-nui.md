# Multiplayer NUI runtime

Target: NWN:EE89.8193.37-17 x64, SHA256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`. Original install and binary remain read-only. All server scripts in this check are authored fixtures, run on an isolated loopback vanilla server. No public commands were sent by the agent during implementation.

## Observed protocol

Native server owners: create inline `1404dd390`, create by resource `1404dd4e0`, destroy `1404dd650`, bind batch `1404dd250`, group layout `1404dd6e0`. These send major55, minors1/2/4/5. The original client receiver `1407a5f20` resolves resource-backed layouts as JUI2083. `CNWMessage::WriteJSON1402db680` writes type16, DWORD byte length and UBJSON; `ReadJSON1402d9f40` reverses that format. JSON strings are UTF8; packet identifiers use the native CExoString codec.

Native client bind queue writer `1407c2da0` sends55/4. Its optional index tail requires server8193.35. Event queue writer `1407c2f80` sends55/3 with token, type, element, array index and JSON payload. Dossier filenames for these two were initially named in reverse; their procedure addresses and subtype calls are authoritative. Twelve original-code writer cases cover empty/single/batched queues and both index-tail branches. Tests compare every defined bit; final native padding retains fixture A5 bits and is masked explicitly. The serializer itself has31 unchanged original-code cases, including scalar boundaries, UTF8, arrays and nested window JSON. Integral-valued native doubles remain D markers; JavaScript numeric values do not retain an integer-versus-double type tag. This does not establish byte identity for that lost type distinction.

`JsonWindow::open14074b6b0` emits `open`, element `_window_`, index-1, null payload. Close owner `14074b3f0` emits the corresponding close event. `LayoutableJ::Construct140741070` attaches click/focus/blur/mousedown/mouseup/mousescroll/range to named elements; shared callback `14073b5a0` forwards the current list index. Payload constructors identify `mouse_pos:{x,y}`, `mouse_btn`, `mouse_scroll:{x,y}`, and range `{a,z}`. Generic click/focus/blur use null payload. Native `JsonWindow::Update14074d750` accepts layout replacement only for a single group or `_window_`. The installed `nw_inc_nui` schema inventory is derived metadata, not a copied script resource.

## Implemented

Connection-owned window/bind state; inline and resource layouts; stable widget DOM; current-window serial guards; indexed arrays; virtualized lists; group/root replacement; open/close and named input events; typed IPC and original packet encoding. Close is locally retired because the server removes its window state after the close event without necessarily sending another destroy packet. Local bind changes occur before asynchronous sending, preventing a late send completion from overwriting an authoritative reply.

All21 stock element types are represented: row, col, group, list, spacer, label, text, button, image button, selectable button, check, image, combo, integer/float sliders, progress, text edit, color picker, options, toggles/tabbar and chart. All8 drawing primitive types are implemented with before/after layers, scissor/hover/button conditions and array bindings. Server strings become text nodes, never HTML. NUI stays below the existing radial portal. Invisible widgets retain their layout space. Native collapsed/title/input flags, centered/cursor placement, size/edge constraints and explicit geometry are supported.

The active connection's `nui_skin.tml`2076, named TTF2074 fonts and images supply the presentation. JUI/TML loose resources now participate in the existing resource precedence. Installed skin QA loads2 named fonts and27 textures. Fonts and decoded images are tied to the active UI-assets owner. Skin reads were initially sequential and first-window initiated; the next build prepares independent resources concurrently during area graphics loading. Timings now distinguish receipt/queue, DOM construction, paint opportunity and skin preparation. Only the two explicit user-mentioned chat triggers are labeled; arbitrary chat/binding values are not logged.

## Validation

`creation-experience-nui-local-v1.json`: unchanged owned `nwserver`, loopback5125, real encrypted connection and actual production renderer. Native scripts accept open, watched edit, indexed list bind, list-row click, group replacement, child and grandchild creation, JUI resource resolution and close acknowledgement. Success=true, renderer errors=[]; ordinary pre-existing unsupported messages remain separate diagnostics. Credentials use the one-use encrypted in-memory fixture channel and are never in reports.

`creation-experience-nui-ui-native-v1.json/png`: actual Chromium DOM using installed skin/fonts/textures,21 types,10,000-row list with15 DOM rows, index47 mutation, preserved edit focus/caret and scroll, nested menus, replacement layout, close, token reuse rejection and connection isolation. Synthetic and installed skin paths are distinct from native-server acceptance. Forty focused NUI/frontend/IPC/level-up checks and the production build passed before the timing follow-up.

Fixture failures are retained in run logs: initial key-in-use rejection16, one admission timeout, authored NCS string comparison aux-code error, fixture close retirement missing in its simplified frontend, and client-side JUI missing from the fixture override. The successful rerun corrected the fixture without changing the original binary/server code. Temporary modules and test BICs stay outside the workspace; no proprietary resources are included in checkpoints.

## Open parity gates

This is generic functional NUI support, not a claim of100% pixel or behavior equivalence. CSS flex layout approximates native kiwi constraints; all default geometry strengths and font atlas metrics have not been oracle-compared. Full TOML syntax beyond the stock scalar/table/font schema, image-region coordinate conventions/scale modes, chart series layout/interaction details, native edit-range events and exact mouse wheel scaling need further comparison. Native unknown-bind/layout-error event behavior and malformed-type diagnostics are not yet reproduced exactly. The live Arelith `-tb`/`-nui` latency report is under measurement; no server-versus-client timing conclusion has yet been established. A current renderer with timing metadata is required for that comparison.

## Scripted overhead prompts and toolbar image follow-up (v46)

The user clarified that toolbar assignment feedback appears above the creature.
Read-only live metadata showed CC18/11 type94 arriving, then being diagnosed as
`network.feedback-format-unhandled`. This is not a missing NUI layout or chat
command. Native script command14051d9d0 produces types93 (TLK) and94 (literal);
formatter1406cb2e0 branches5d/5e resolve the target with1406ab9e0/1406d8100 and
call140766a70 ->CGuiInGameFloatyText972300/972750/972840. The target ID is used
unchanged, including descending external character IDs such asfffffffe. No
special local-player sentinel conversion is added.

New presentation uses the existing native float owner: white RGB, galahad14,
shadow flag0,1.5-second lifetime and native rise/fade. Script prompts bypass the
combat-feedback toggle. The independent show-in-chat field must equal1 to echo
through the original color/flags128 path. Type93 parses TLK with nativeB8/BC0;
type94 keeps the literal server text.64 unchanged original formatter cases cover
creature presence, flags0/1/2 and signed integer boundaries; actual Chromium
renders the installed bitmap font, projects the prompt and verifies chat echo.
Removed/noncreature and stale-connection output are rejected without gameplay
mutation. No Arelith prompt text is hardcoded.

Native image-button callback14095c800, reached through factory14095d710 and its
vtable140e6e3e8, uses image regions in PIXELS, casting to uint16. Only positive
width AND height select a subregion; null/zero/negative extents retain the full
image. The previous normalized crop could blank or distort toolbar icons.
Eight original-code cases verify the gate, fractional truncation and wrapping.
The shared image helper now caches per active assets owner and crops in pixels.
Image bindings also invalidate pending loads when cleared, restore the same icon
when reassigned, and reject late completions after a clear/reassignment race.
The rendered fixture checks all these cases plus a headerless12-slot toolbar.

Bounded layout diagnostics now record geometry, header flags and at most32 image
resource names/regions, without labels or arbitrary binding values. This will
help diagnose any remaining live toolbar geometry mismatch.92 focused tests,
synthetic and installed-resource Chromium fixtures, and production build PASS.
User approved restart:8168 closed normally;14800 opened at Main Menu with
index-n7UVY09z.js, launcher controlv6/exec49643. No automated public join or chat
was sent; Arelith visual/latency acceptance remains pending user reconnection.
Prior owned native-server acceptance predates this follow-up; it is not relabeled
as a new full-server test. Full kiwi geometry, all image aspect modes, edit-range
and other open parity gates above remain.

## Empty-title toolbar clipping (v47)

User reports the bottom50% of toolbar boxes cut off. New live bounded metadata
identifies empty STRING titles, literal collapsed=false and closable=false,
transparent/borderless windows544x48 with40x40 slot dimensions. Our earlier
fixture used title=false and missed the empty-string branch. The unwanted26px
header consumed roughly half the entire toolbar height, squeezing/clipping slots.

Native Window::SetTitle1406c7310 clears flag0x40 when its string length is zero,
otherwise sets it, preserving all other flags.21 unchanged original-code cases
verify this across title lengths and flag combinations, with the already-owned
string path (allocation/self-copy not tested). JsonWindow::Render14074b810 calls
base layout render1406c44e0; source binary/build hash remains unchanged.

The renderer now derives title visibility from the resolved title string length
and independently retains close/collapse controls. Async localized titles also
refresh header visibility. Empty/nonempty bound titles restore/hide the header
without replacing slot DOM. Regression uses the actual544x48 geometry and both
literal empty strings and bound titles, measuring full40x40 slots with zero
bottom clipping. Six populated toolbars/72 slots use installed spell icons,
66 yellow counter/X layers and6 draw-list images. Actual screenshot inspected;
synthetic and installed-resource fixtures,92 focused checks and build pass.

This is a verified clipping correction, not a new full kiwi/skin pixel-parity
claim. The older live session supplied only one ordinary image-button identifier
in its bounded metadata; draw-list resources were not covered by that original
metadata helper, so that does not prove all other received slots are empty.
No server assignments are fabricated. Agent sent no public chat or join.
Replacement14800/exec49643 exited normally; the corrected build was opened at
Main Menu for user reconnection under the existing restart authorization.
