# Native Resolution/UI Scaling — windowed integration

## Maximize/fullscreen resize correction (2026-10-28)

The user reported a letterboxed, horizontally compressed Settings page with
unusable clicks after maximizing. The resize listener was changing content
scale synchronously inside the engine's `size_changed` emission. In the exact
engine build (`ed1daf0bf001b61586d9930840f2f1394092c079`),
[`Window::_update_viewport_size`](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/scene/main/window.cpp#L1302)
calls `Viewport::_set_size` before attaching its local screen rectangle.
`_set_size` emits the signal. Our nested update could therefore be followed
by the outer call attaching its stale rectangle, while the logical viewport
and input transform already described the new size.

`native_window_settings.gd` now coalesces notifications into a deferred update,
reads the final client dimensions, and skips unchanged scale setters. This
avoids modifying the viewport during its unfinished screen attachment. Its
snapshot now includes physical/base/logical dimensions, transform, mode and
monitor for future reports. Preference behavior and the 3D resolution are
unchanged.

`native-window-resize-reentrant-baseline-v1` reproduces the synchronous-update
failure against the previous owner. `native-window-resize-fixed-v1` passes72
checks covering maximized/fullscreen/windowed restore, Windows display-server
notifications, burst resizing, 1x/1.5x scale, physical button pixels/input and
nonactivating secondary-ultrawide use (3440x1369 maximized,3440x1440 fullscreen).
`native-video-resize-regression-v1` passes37 existing native-menu, scale,
static3D-pixel and camera/input checks. Both passing debugger receipts pin
unchanged sources and report no engine/lifetime errors or public connections.
The pixel assertions inspect the render target; they do not independently
capture Windows' final screen attachment. A manual Windows maximize retest is
still required to confirm the user's exact symptom is resolved. Full original
video-mode control and complete UI parity remain open.

In-game Options now opens the original Resolution and UI Scaling page. Native
Godot owns its original372x384 frame, runtime captions, nested scale label and
arrows, mode rows, animated scrollbar and Apply/OK/Cancel/X actions. The page
drags by its original title and retains its position. This is windowed scaling
integration, not complete video settings or entire UI acceptance.

## Owners and behavior

- `native_video_options.gd` reads GUI/model resources from the current session
  catalog, borrows its original painter/fonts, owns pending/applied page state
  and rejects held clicks from a retired scope. It uses the existing original
  timer-button repeat policy. Source glyphs paint above their label background.
- `native_window_settings.gd` applies the original float scale policy to this
  application's canvas, preserves independent preference keys, and joins its
  read-only query worker on retirement. Preferences use the replacement's
  native ConfigFile; original profile files are untouched.
- `native/window_modes.c` only calls read-only Windows monitor/mode APIs. It
  accepts no input paths, reads no profile, opens no window and changes no
  desktop mode. The worker checks the source/builder/binary manifest before
  executing it. `join-native.ps1` builds it when stale, independently of the
  already-running renderer DLL and manual game instances.
- `native_main_menu.gd` enables Resolution only when its actual native owner
  exists, hides the parent while the child is open, restores that parent on
  return and retires the child before its borrowed session resources. Shutdown
  dismisses the menu before retiring its settings service.

Arrows change a pending value in original0.1f increments. Apply updates the
actual UI scale while keeping the page open. OK applies then commits and
returns. Cancel/X/Escape before Apply discard the pending edit; after Apply,
closing commits the applied value and discards later unapplied edits. Reopening
starts from the actual scale. Connection/area/control changes cannot retarget
a held Apply. Existing particle/creature-slot settings are preserved.

The original initializer disables mode selection. This version preserves a
read-only list rather than exposing an inactive resolution-changing button.
Further original mode-enable/fullscreen branches remain unaccepted. The
additional original GetVideoModes dossier shows the800x600 minimum, duplicate
caption suppression and exact `%ix%i %ihz` formatting. SDL provides descending
dimension/depth/refresh order; the native Windows query is normalized to that
[documented SDL order](https://wiki.libsdl.org/SDL2/SDL_GetDisplayMode).
It queries the monitor containing this game to respect secondary-monitor use;
the original routine literally queries SDL display0. Exact multi-monitor mode
inventory comparison remains open.

UI scaling uses Godot's
[Canvas Items mode](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html),
which keeps rendering at the physical target resolution. Tests compare actual
static3D pixels before/after scaling, physical target size, native-button input
from physical coordinates and camera projection/picking coordinates. Camera
motion uses [unscaled screen deltas](https://docs.godotengine.org/en/stable/classes/class_inputeventmousemotion.html#class-inputeventmousemotion-property-screen-relative);
Follow normalization also retains physical width. Free and original Follow
camera sensitivity therefore remain independent of the UI scale.

## Evidence

The [original data/float milestone](NATIVE-VIDEO-OPTIONS-RESEARCH.md) retains
the source layout and437 unchanged original-instruction scale cases. Further
read-only dossiers under `../backups/animations`:

- `rea-native-video-modes-v1.json`: actual original mode enumeration/filter/
  formatting/deduplication function and full video-panel vtable bytes.
- `rea-native-video-lifecycle-v1.json`: activation and Escape/Cancel routing.

All target original client SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

Current debugger-backed receipts total787 scoped checks, including437 original
float cases and existing gameplay regressions, not787 distinct video actions:

| Receipt suffix after `native-video-page-` | Checks |
| --- | ---: |
| `data-final-v5` |467 |
| `input-final-v4` |37 |
| `menu-final-v4` |35 |
| `desktop-final-v3` |41 |
| `settings-final-v3` |38 |
| `layers-final-v3` |16 |
| `retirement-final-v3` |20 |
| `server-final-v4` |133 |

Actual isolated native input covers source controls, glyph pixels, pending
state, Apply/Cancel/OK, preference preservation, dragging/retained position,
scope retirement, outside clicks, WASD and middle mouse. Physical-window input,
unchanged world pixels and both camera paths are checked separately. Normal,
applied and actual-server video screenshots were reviewed. Tests inject events
into owned viewports and never capture or warp the physical cursor.

The unchanged original server on127.0.0.1:5125 verifies the real menu route,
mode query, pending arrows, live scale application with the same authoritative
actor/connection, return to Options and remaining original gameplay actions.
Source hashes stay unchanged, debugger traps remain armed, native exit is0,
workers drain and the port is released. The existing wind-sampling warning
remains; no script/lifetime error or native exception is accepted. Startup is
nonactivating on a nonprimary monitor, and shutdown reports unfocused. There
are no public connections or FPS/performance acceptance claims.

Failed candidates remain retained: the initial service collided with Node's
`ready` signal; the first persistence test compared a saved decimal directly
with a float32 value rather than its reload conversion. Visual review caught
and corrected label-background coverage of arrow glyphs. The first desktop
regression waited for only one of the two quickbar art owners; its corrected
gate waits for both and retains the immediate rebuild-art assertion.

`tools/audit-native-video-options.mjs` verifies current receipts, original
evidence, helper identities, cleanup and rollback, then writes
`reports/native-video-options-acceptance-v1.json`.
Rollback: `backups/native-video-options-v1.zip`, read-back verified.

Remaining: real resolution/fullscreen changes and all mode-enable branches,
pregame integration, direct original-client visual/input/monitor comparison,
all keyboard/default-focus/tooltip/localized/custom-resource variants,
automatic-scale persistence across resolution changes, exact original config
serialization and all preference/query error/timeout paths. Default replacement
scale remains1 unless configured; original first-run default parity is not
claimed. The [entire UI goal](NATIVE-UI-PARITY-GOAL.md) stays active.
