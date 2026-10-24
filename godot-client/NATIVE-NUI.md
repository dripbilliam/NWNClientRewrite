# Native server NUI

Status: native multiplayer foundation verified on the owned local server. Full NUI parity,
the complete client migration, and moving-world performance remain incomplete.
No Arelith connection was made.

## Implementation

`tools/nui-service.mjs` projects the existing connection-owned `NuiState` into
native controls using private window/control handles. The existing UBJSON
decoder, text formatting, skin parser, image crop/raster helper, and typed NUI
packet writer remain the protocol/resource sources. Godot owns the visible
windows and drawing. The isolated v28 staging build disables its hidden DOM NUI
view to prevent duplicate open/input events; the working main/dist are retained.

All 21 existing element kinds have native implementations: row, col, group,
list, spacer, button, image button, selectable button, check, label, text,
image, combo, integer/float sliders, progress, single/multiline text edit,
color picker, options, tabbar and chart. All eight draw command types reach the
native canvas. Lists request visible ranges while retaining original row
indices. Invalid/replaced handles cannot select arbitrary bindings/elements;
one unsupported layout no longer prevents other valid windows from updating.

NUI is owned by the connection and server window serial, independently of area
and controlled-creature lifetimes. Native windows share the ordinary gameplay
overlay and stacking, remain nonmodal, support title dragging/resizing/collapse,
and use original skin resources/fonts and images. Resource delivery is bounded,
chunked, hashed, and retired with the connection. Native close and server token
replacement retire their control handles. Passive windows pass world clicks
through. A titleless 50-pixel toolbar has no title padding and displays complete
48-pixel buttons with the original 32-pixel icon crop.

Editing preserves stable controls, focus and caret. Reassigning an unchanged
Godot LineEdit maximum was resetting the caret; the setter is now conditional.
Private input revisions additionally prevent an older queued projection from
erasing a newer local draft. After acknowledgement, authoritative server text
replacements are applied normally.

Indexed binding changes send the complete updated array plus the changed-row
index. The native server was observed storing a scalar when only the cell value
was sent, even while reporting the correct index to the watch callback. The
existing session owner has an opt-in `wholeValue` path so native whole-array
input updates optimistic local state without nesting arrays. Existing callers
retain their previous API behavior. A verified source backup precedes this
shared-session change.

## Server action completion

The native NUI targeter now has an actual local callback acceptance check. The
child menu requests targeting; choosing the player passes through the existing
typed script-target provider and the native server acknowledges that same
player. The toolbar image button independently requests a cast target. Its
server callback uses AssignCommand and the installed nine-argument
ActionCastSpellAtObject API to queue Light without cheat or instant-cast flags.
Replicated prepared uses decrease from 2 to 1, and the normal incoming cast
animation record is observed. This is scripted target selection through the
native targeter, not physical-device acceptance or full spell visual parity.

## Connection retirement and saved-character reconnect

The owned local test now exports and disconnects with NUI open, reconnects using
the exact saved BIC bytes, and repeats the controls, server targeting/cast and
A–B–A flow. Two read-back hashes match the saved disconnect version; all three
exports retain one temporary regression vault identity. No user vault is changed.

The native NUI manager records weak references to retiring windows and decoded
resources. At the next admission, all old window/font/image references are gone.
A close request deliberately tagged with the old connection is rejected before
dispatch, even though the new root reuses the same private window ID. Old backend
resource jobs are retired with zero pending work. This verifies normal reconnect
with loaded menus; disconnect during unfinished resource/text jobs remains open.

## Test evidence and failures

- `reports/native-nui-reconnect-local-v2.json`: **39 +41 NUI checks pass** across connections 1 and 3, six rendered/animated area admissions, two complete server action phases and three versions of one temporary saved character. The second phase independently checks zero old native windows/resources and rejection of the colliding old-connection close. Canonical state, actual casts, exit 0, no engine errors, disconnected and zero pending resources pass. The second-session screenshot was reviewed.
- `reports/native-nui-reconnect-node-v1.log`: 51 checks pass; `nui-reconnect-ui-native-v1.json` has 15 native checks, including decoded resource retirement.
- `reports/native-nui-actions-local-v1.json`: **16 dialogue/examine +39 native NUI checks pass** with the additional required action gate. Two actual script-target submissions are acknowledged by the native server and a NUI-triggered Light cast consumes a prepared use (2 to 1). Canonical 2,000-row state and all three rendered A–B–A admissions still match; exit 0, no engine errors, disconnected, zero pending resources.
- `reports/native-nui-actions-node-v1.log`: 50 checks pass, including rejection of a fake action pass without server target acknowledgement and actual use consumption. `nui-actions-ui-native-v1.json` retains all 14 native checks; `native-nui-actions-authored-v1.json` has 11 offline authored bytecode/ABI checks.
- `reports/native-nui-local-v8.json`: **16 dialogue/examine and 34 native NUI checks pass**. The server independently returns all 2,000 array values with exactly row 1999 changed and the watch callback index 1999. Three A–B–A admissions each have an actual rendered/animated presentation; retired world owners are zero. Native exit 0, no engine errors, disconnected, zero pending NUI resources. The screenshot was visually reviewed for original art/fonts, nested windows, list rows and full toolbar height.
- `reports/native-nui-node-v9.log`: 49 checks pass, including the existing legacy
  NUI regressions, typed whole-array packet/state handling, private handles,
  disabled ancestors, window replacement, queued drafts, resource retirement,
  and acceptance gates.
- `reports/nui-ui-native-v10.json`: 14 native headless checks pass, including
  original handle retention, queued-draft protection/server replacement,
  unclipped toolbar height, virtual range requests, passive-window input,
  resource decoding and all eight draw primitives. Engine log is clean.
- `reports/native-nui-local-v6.json`: every visible native assertion passes, but
  the run is **rejected** because the independent server check found its indexed
  binding had become a scalar. It is not accepted as correct multiplayer state.
- `reports/native-nui-local-v7.json`: 34 native checks and the complete 2,000-row
  server-array comparison pass, including actual native GUI clicks, watched
  text/typed controls, group replacement, resource-backed grandchild, original
  fonts/images, toolbar token reuse, script-target activation, simultaneous
  camera/WASD/outside click movement and A–B–A with stable NUI owners. This run
  remains **rejected**: the test left the middle area before its deferred
  screenshot completed. The next run waits for the actual completed frame.

Earlier failures are retained. The first reconnect attempt failed only its second dialogue screenshot: the evidence filename was already occupied by the first connection. Both gameplay and NUI screenshots now include their connection identity, preserving separate evidence. The first authored large NCS string literal
stopped native initialization before its list data completed. Smaller
concatenated literals preserve all 2,000 rows and run successfully. This is an
observed fixture boundary, not a claim of a fully reverse-engineered VM limit.
The original v1 host report inherited dialogue success incorrectly; its
`native-nui-local-v1-review.json` explicitly rejects it. NUI acceptance now has
an independent final gate and cannot inherit success from dialogue/clean exit.

The foundation server module is GodotNui5; GodotNui6 adds target/spell callbacks. Its resource-backed menu is an authored
JUI exposed in the owned local profile's override folder: the API requires the
resource on the client. No installed game file or real server reply is replaced.
Only the local NUI smoke mounts that profile as client content.

## Installed skin adapter

`systems/nui_theme.gd` now maps installed skin tables onto native controls:
button/selected-tab states, checkbox and radio artwork, editor padding,
combo arrow and dropdown panel, slider cursor, progress fill, window header
buttons, group borders, chart backgrounds and scrollbars. Check and radio
marks are composed at original dimensions from the original images in memory.
Styles and composites are cached across unchanged binding updates and retire
with the connection. No installed artwork is copied into project source.

`reports/native-nui-skin-local-v2.json` passes **49 +51 native NUI checks**
over two actual local connections. Both phases verify nine installed skin
properties, watched canonical state and actual normal spell consumption. All
six rendered/animated area admissions pass; previous native windows/resources
are zero, stale input is rejected, saved-character read-back matches, native
exit is 0 and no pending NUI work remains. The second-session screenshot was
visually reviewed, including original fonts, radio/check marks and full-height
toolbar icons. This is functional/style evidence, not a clean FPS benchmark.

`nui-theme-authored-v4.json` passes 19 authored texture/style/readiness checks;
`nui-theme-ui-regression-v2.json` retains all 15 native lifetime/input checks;
both engine logs are clean. `native-nui-skin-node-v2.log` has 52 passing checks.
The first live skin run is retained as rejected: its hard-coded total included
an image belonging to a child window that had not opened yet. Readiness now
checks the actual referenced skin images/fonts and completed native restyling.

Full pixel/state equivalence is still pending. In particular the installed
font's fractional horizontal spacing (0.5) cannot be represented directly by
Godot FontVariation's integer spacing property; broader popup interaction and
disabled/focus/pressed-state visual comparisons still need acceptance.

## Popup input and pending-work guards

Dropdown and color popups now contribute their complete rectangles to world
pointer blocking, including the area beyond the parent menu. Disabling or
hiding a control, making a window passive/collapsed, replacing a control, and
retiring its connection dismiss active popups rather than leaving a floating
input owner behind. Embedded and desktop-window coordinate spaces are handled
separately; the live check accepts the embedded path only.

`reports/native-nui-popup-local-v2.json` passes **57 +59 NUI checks** across
saved-character reconnect. Eight additional checks per phase use actual native
GUI hit routing to open both popup kinds, navigate a dropdown with keys, type a
color hex code and dismiss with Escape. The independent native server echo
matches the canonical choice and RGBA values. All previous 2,000-row binding,
normal spell-use, simultaneous-menu movement, six animated admissions, stale
input rejection and resource-retirement requirements remain enforced. Native
exit is 0, no engine errors are reported, and pending resources/old owners are
zero. The second-session screenshot was reviewed. The first live popup run is
retained as rejected: a strict dictionary comparison in the probe rejected the
JSON numeric representation despite the correct independent server echo; the
probe now compares each numeric channel explicitly.

`reports/nui-popup-fixed-v3.json` passes 16 authored native checks, including
popup bounds beyond the parent, typed color entry and revocation before deferred
deletion. `nui-popup-ui-regression-v1.json` retains 15 native UI checks and
`nui-popup-theme-regression-v1.json` retains 19 skin checks. Logs are clean.

Pending-work investigation reproduced a backend lifetime bug: a localized text
lookup completing after retirement could queue a new image and repopulate the
old resource map. Resource admission and text completion now require a live
owner. The retained `nui-pending-before-v1.log` fails that regression; the full
`native-nui-popup-node-v2.log` passes 54 checks after the fix.
`nui-pending-native-v1.json` separately passes eight authored races through the
production connection receiver: old fragments and commits are ignored even
when transfer/window/version IDs collide with the new connection, new bytes
still pass digest verification, and the new window commits and retires cleanly.
This is authored race coverage, not a forced pending-work live reconnect test.

## Large JSON transport

The ordinary bridge frame cap remains one MiB. NUI projections and edits now
use `tools/nui-packets.mjs` / `systems/nui_packets.gd` when their serialized
UTF-8 payload exceeds 60,000 bytes. Each fragment stays below 60 KB; complete
payloads are bounded at 16 MiB and checked for length, SHA-256, ordered parts,
connection and message owner before dispatch. Reassembled inputs still pass
the same private window/control and canonical binding checks. Reset releases
partial assembly. No original network protocol or general bridge cap changes.

`reports/nui-large-transport-native-v2.json` passes 11 authored native checks,
including exact Node-to-Godot preservation of a 1,260,000-byte description on a
real native tooltip owner and cleanup. `nui-large-transport-roundtrip-v2.json`
verifies 43 Godot-produced packets reconstruct the exact 720,000-character edit
through the real JS NUI service's canonical validation (1,440,002 JSON bytes
for the text value). `nui-large-node-regression-v1.log` has 59 passing checks.
`native-nui-large-regression-local-v1.json` retains 57 +59 actual local NUI
checks over saved-character reconnect with clean exit/ownership cleanup. That
live regression uses the existing menus, not a server-originated giant menu.

This accepts transport, not giant visible-text layout. The retained opt-in
`tests/nui_large_widget_stress_test.gd` exposed an unaccepted native widget case:
the valid million-character label/edit attempt consumed over 96 CPU seconds
without completing and was stopped. Follow-up text/theme profiles below isolate
repeated styling and Unicode layout costs, but do not accept this case. An earlier attempt used embedded NUL and
produced native text warnings; that fixture is invalid for this acceptance.
Visible huge-document rendering, huge edit responsiveness and embedded-NUL
semantics are not accepted by these transport tests. See the retained logs
`nui-large-native-v1/v2/v3.engine.log` and `nui-large-before-v1.log`.

## Text theme profiling and retained native edit failure

`systems/nui_theme.gd` now batches each complete control, scrollbar and popup
theme change into one native notification. Ordinary controls receive only their
`font`/`font_size` items; rich text retains all five native face/size items.
`nui_element.gd` installs text-control styling before assigning a new document
and sets a changed single-line length limit before replacing its value. Original
fonts, text, native editor widgets, caret/selection and input revision ownership
are retained; there is no prefix truncation or replacement text renderer.

`tests/nui_text_profile.gd` is an opt-in, flushed stage profiler, not an
acceptance test. The first `nui-text-profile-20k-v1.jsonl` run actually generated
16,670 characters (its generator was subsequently corrected): label styling
took 3,236 ms and single-line styling 4,679 ms, with native break-insert errors.
The corrected, 20,000-character `nui-text-profile-bulk20k-v1.jsonl` completed
without those errors: the corresponding styling stages took 446 and395 ms.
These are different character counts, so they do not establish an exact speedup
ratio. A production notification probe independently verifies one notification
for a complete skin update and none for an unchanged refresh.

`reports/nui-text-theme-only-v3.json` passes13 headless production theme,
20,000-character preservation, caret/selection, stale-refresh and retirement
checks. `nui-text-theme-rendered-v1.json` repeats those13 checks on actual Vulkan
Forward+ with a clean engine log. Its scope is explicitly **theme-only**.
The existing skin/UI/popup/pending-owner regressions pass19/15/16/8 checks;
`nui-text-popup-rendered-v1.json` also passes16 real-renderer popup checks.
`nui-text-theme-node-regression-v1.log` has29 passing backend checks.

Long Unicode editing is still **unaccepted**. The default full
`tests/nui_text_theme_test.gd` types a real native GUI key after the above theme
checks. `nui-text-edit-rendered-v3` terminates at that insertion with Windows
exit `-1073740940` (`0xC0000374`); the independently saved exit evidence is
`nui-text-rendered-exits-v1.json`. Earlier headless full attempts also failed.
The standalone profiler reproduces the same exit on a 20,000-character native
LineEdit without the NUI manager, protocol, server or production adapter, both
with automatic font fallback and an explicit emoji fallback. The 20,000-ASCII
and10-Unicode diagnostic insertion cases complete. These isolate a native
large-Unicode editor problem; they do not prove its C++ root cause.

An explicit fallback improved single-line shaping in the diagnostic, including
a million-character assignment completing in938 ms, but was **not** installed
in production: the crash persists, and glyph/fallback fidelity is not accepted.
The100,000-Unicode profile still spends about1.55 seconds laying out a label
and5.3 seconds assigning a multiline document. Large-document layout and input
remain unaccepted. The user explicitly deferred the emoji/native-text-server
investigation so ordinary migration work can continue. The diagnostic engine
build was stopped; the pinned production engine, incoming text and font fallback
remain unchanged. Retained failures are not acceptance claims or a current
migration blocker. Any future investigation should preserve complete text,
selection, IME, clipboard and undo behavior.

The cross-feature local run `native-nui-text-theme-local-v1.json` is retained
as a failure: ordinary popups had become native OS windows after the separate
debug-window feature changed the project-wide setting. The ordinary popup test
previously hid that regression by forcing embedding itself. The project now
embeds ordinary gameplay windows; diagnostics alone uses `force_native` while
hidden. `nui-window-popup-rendered-v2.json` passes17 actual Vulkan checks without
a test-only project override, and `nui-window-settings-rendered-v1.json` passes21
including the separate nonmodal OS debug window. The intermediate local v2
attempt is also rejected: setting `force_native` before clearing the default
visible flag emitted an engine error, despite its16 gameplay-text checks passing.

With that initialization order corrected,
`reports/native-nui-text-theme-local-v3.json` passes57 +59 actual local NUI
checks across saved-character reconnect and six animated area admissions.
All popup checks, original artwork, full toolbar height, actual normal Light
consumption (2 to1), typed canonical binds, stale input rejection and native
owner cleanup pass. Native exit is0, no engine or renderer errors are reported,
and pending NUI resources are zero. The second-session screenshot was reviewed.
`native-nui-window-settings-local-v1.json` separately passes25 actual Windows
settings/store/debug checks without connecting to any game server; the original
credential/mod profile is unchanged. These accept the ordinary local UI
regression, **not** the retained huge-document layout/edit failure or full NUI
and moving captured-world performance parity.

## Remaining acceptance

Authored menus across two real owned servers now pass A→B→A with14/17/17 native
checks, watched edits, child JUI loading from distinct HAKs under the same resref,
server callbacks, reused tokens/handles and stale-input fencing. All retired
windows/resources are freed. See [NATIVE-NUI-HANDOFF.md](NATIVE-NUI-HANDOFF.md)
for evidence and limits. Production transfer adoption remains disabled pending
server-vault reference and NWSync handoff checks.

Full skin/style equivalence for all native widget states, charts/draw edge cases,
broader popup keyboard/mouse behavior and native-window popups, huge individual text/layout payloads, broader
server action/failure cases, disconnect/reconnect while resource or text work is
still pending, and physical-device/fidelity review remain required.
The authored million-row metadata check materializes a bounded viewport; it is
not evidence for a million fully populated server rows. No NUI or full-scene
performance acceptance is claimed. Local scripted control dispatch is not a
substitute for physical-device acceptance.
