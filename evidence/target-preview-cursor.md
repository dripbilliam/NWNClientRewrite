# Spell area previews and native world cursors

Implemented after the user's request for spell area previews and mouse status
icons. No active client restart, automated Arelith action or original process
modification was performed. The broader goal remains paused; source is unsealed
after checkpoint49.

## Native inputs

Read-only NWN:EE89.8193.37-17 x64, SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.

Spell target setup140704720 reads shape/size/flags from CNWSpell1a4/1a8/1ac/1b0,
registers cursor29, resolves range through140704a50 and calls140704bd0. The range
owner maps exact P/T to the touch range and S/M/L to the active range entries.
The installed spells table confirms sphere/rectangle/cone/hsphere names and
fractional dimensions, e.g. stock Fireball6.67. The actual shader inc_target.SHD
defines shapes0..4, its signed-distance math, caster-origin adjustment, out-of-
range translation/dotted line and pulsing fill/outline. It is loaded through the
active resolver at runtime, rather than copied into the repository.

Receiver1407b1340 handles57/1 per-spell shape overrides and57/2 configuration for
the next EnterTargetingMode call. Both are now decoded and connection-owned.
Native API comments and the existing98d5f0 owner clarify a previous naming error:
the third18/23 DWORD is the invalid-target cursor, not target-preview flags. It
is now badCursor throughout the decoder/controller; the original mask fixture
metadata was renamed to match. The separate57/2 flags field remains unchanged.

Cursor resources are the original gui_mp_* up/down sprites. Installed cursors.2da
maps named entries to native IDs. Original resource strings and installed nwscript
MOUSECURSOR constants establish default/door/use/talk/attack/magic/invalid/pickup,
run/walk directional arrows and custom00..99 mappings. Native misc-visual field260
is MouseCursor, default-1; the existing wire decoder provides it as light.field260.
The cursor view honors that field and local nativeMiscVisualFields260 before
ordinary hover policy. Active resource/table overrides stay with their owner.

Preview color selection follows140704bd0. Original settings.tml schema defaults
and this user's matching settings are dangerous #ff0000ff, harmful #0000ffff,
helpful #00ff00ff and other #ffffffff. A preliminary search at14001adf0 found
an unrelated console initializer; it is not evidence for these colors.

## Presentation and ownership

Casting metadata now includes TargetShape, FLOAT TargetSizeX/TargetSizeY and
TargetFlags. Previews use the selected family child, feat or item definition and
active ranges table, with connection-specific per-spell/server target overrides.
Target validation is read-only. Previewing does not send casts or change server
positions, availability or effects.

The native targeting shader is namespaced and desktop GLSL syntax is normalized
for WebGL. Fragment world positions are converted back to NWN axes. It composes
with existing native camera-keyhole/material hooks without cloning animated
materials or severing their controller references. Hierarchy revisions discover
new meshes and retire removed material hooks. Area teardown restores hooks before
keyhole teardown. Missing shaders/cursor assets report explicit diagnostics.

The canvas receives original cursor PNGs decoded in memory through NativeUiAssets;
no cursor files are extracted into the workspace. Regular hover distinguishes
doors, transitions, usable objects, creatures, hostility, pickup and walkable
ground. Targeting selects valid/invalid and pressed/released native cursor IDs.
World pointer/preview input yields to menu hit targets, loading, modal capture and
camera/game lifecycle guards. Owner changes reject stale asynchronous cursor loads.

Open comparison limits: browser cursor hotspot/UI scaling and exact native hover
policy for specialized actions still need live comparison. Ground shape math is
the installed shader, but original per-creature preview eligibility, all native
settings import and custom module shader uniforms are not claimed complete.
The local animation clock drives the pulse; native timer phase is not matched.

## Validation

42 focused tests pass: active FLOAT dimensions/ranges/shapes, original native
cursor constants, closed/open door transitions, usable/static objects, server
cursor overrides, target validation,57/1 decoding/truncation, connection isolation,
existing NUI/script targets, spells/feats/families and camera input.

Actual Chromium WebGL fixture runs installed inc_target and inc_keyhole together
on authored non-flat terrain. All four shapes and range-only mode change rendered
pixels; clearing returns exactly to baseline. Native mouse events verify magic,
invalid, pressed/released cursors, menu suppression/restoration and hook cleanup.
Ten installed cursor images are loaded. No renderer errors, joins or uploads.
Screenshots for sphere/rectangle/cone/ring/range were visually inspected.

Initial fixture runs did not set Electron's held-button modifier; pointer.buttons
was zero. The corrected native input supplies leftButtonDown, and the adapter
also uses the triggering button on pointerdown. An initial screenshot preceded
the paint opportunity; final shape screenshots wait two frames. These earlier
failures are retained and not counted as passing runs. Final browser run-v5 exits0.
The previous actual-Chromium NUI toolbar target selection regression also passes.

Build index-BMHmLIoe.js/index-8ID_vg9F.css passes. Reports in backups/animations:
target-preview-cursor-resources-v1.json, target-preview-cursor-focused-v3.txt,
target-preview-cursor-ui-v1.json, target-preview-cursor-ui-run-v5.txt,
target-preview-cursor-build-v2.txt and target-preview-shape-{0..4}-v1.png.
New fixture/code is authored; no proprietary raw shaders, models or textures
are stored. Live Arelith preview/cursor acceptance remains for the restarted client.
