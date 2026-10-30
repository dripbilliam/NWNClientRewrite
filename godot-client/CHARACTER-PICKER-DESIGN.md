# Character picker redesign

**Current default,2026-10-29:** the user requested a return to the original
character-picker style. Normal launches now use the source-defined native
chooser with its original list, record/Server Info/Players tabs and controls.
The redesign below is historical and remains available only through the
explicit diagnostic `--modern-picker=true` argument. Selection acknowledgments,
native BIC/record decoding, local Delete, preferences and appearance-cache data
remain intact; the separate full-screen3D stage is not part of the original UI.

User direction,2026-10-29: this screen may differ from the original binary.
It must appear immediately, look considered rather than like monochrome boxes,
and should show the selected character in3D. This exception changes appearance,
not native ownership, server authority, active resource rules or action parity.
The other original-game UI screens retain the existing parity requirement.

## Research

- [Guild Wars2 character selection](https://wiki.guildwars2.com/wiki/Character_select)
  separates character slots, selected-character information, a model preview
  and Play/Create/Delete. Its background examples also illustrate the cost of
  elaborate animated scenery. Use the clear hierarchy, keep our stage simple.
- [FFXIV official Getting Started manual](https://na.finalfantasyxiv.com/game_manual/start/)
  separates server/data-center selection from character creation. Its character
  presentation supports model rotation and zoom. Keep the current server visible
  and restrict drag/zoom to the preview rather than consuming list input.
- [Godot SubViewport documentation](https://docs.godotengine.org/en/stable/classes/class_subviewport.html)
  supports an independently displayed3D scene and visibility-driven updates.
  Use one native preview, not a viewport/rendered model per roster entry.

## Chosen design

A full-window composition: a readable roster on the left, an illuminated
character stage in the center and a concise selected-character summary with
one prominent Enter World button on the right. Narrow windows stack summary
below the preview. The top line shows server identity and connection status;
Server Info and Players remain accessible. The bottom carries New Character,
the pregenerated filter and Back. Destructive actions stay separate from Play.

Use warm ivory text, dark blue/charcoal surfaces, restrained antique-gold rules
and a strong amber selected accent. Portrait-led rows have name, classes/levels
and an explicit Local/Server source badge. Use generous spacing, text hierarchy,
subtle gradients and a lit stage rather than tiled button outlines. Preserve
original models, palettes, textures and server content; no painted stand-in
for the selected character.

## Immediate path

Construct the entire shell from native Controls/CanvasItem drawing before any
archive, font, model, bitmap, GPU preparation or network reply is awaited. One
stable screen appears immediately; do not display the generic chooser and swap
it later. Populate authoritative rows as their actual server data arrives.
Local metadata is decoded off-thread. Fonts/portraits enhance existing rows
without rebuilding selection or moving controls under the pointer.

Selection, Play, Back, server information and roster actions retain connection,
row identity and acknowledgement guards. Play depends on actual server admission
state, not a3D viewport or a decorative texture finishing. An unavailable preview
must not prevent joining an otherwise valid selected character.

## Selected-character stage

Prepare only the selected character, on the existing native asset/creature
pipeline. Show a portrait while the real model is pending. Idle animation,
drag-to-turn and wheel zoom run in a bounded private SubViewport; no particles,
shadow-heavy scenery or background world is required. Hide/retire the viewport
when leaving the picker. Bind all work to connection + selected key + BIC digest;
late work must not replace another character's preview.

Server-preview bytes may arrive later than the roster. Appearance/equipment
must come from those actual bytes; derive nothing from class names or portraits.
Active server2DAs, HAKs, overrides, NWSync and custom TLK remain authoritative.

## Acceptance still required

Measure first-shell frame separately from roster receipt, data readiness,
preview preparation and Play admission. Verify at least1280×800 and3440-wide,
resize/fullscreen, keyboard and pointer selection, repeated selection while
assets are pending, server rejection/cancel/disconnect, actual original-server
Play, and offscreen preview retirement. Review real native screenshots and
report measured timings rather than calling delayed data instant. No new
automated public connections; preserve the user's manual client session.

The first native shell is in `systems/native_character_picker_shell.gd`.
It constructs synchronously without resource workers and separates input
capabilities from the preview slot. Headless and graphical fixture checks cover
initial construction, selection/Play before images, connection changes during
held input, selected-row changes, refusal and empty lists. The initial headless
construction measured8491 microseconds on this machine; this is a shell-only
measurement, not server roster arrival or end-to-end loading time.

`native-picker-shell-headless-v2` passes11 checks and
`native-picker-shell-graphical-v1` passes12. The graphical screenshot is an
explicit sample-data layout scaffold. Its empty flat preview panel and missing
row portraits are not the final visual design and are not accepted as satisfying
the request for a polished picker. The next visual pass must incorporate the
lit native stage, portrait-led roster and proper artwork hierarchy.

The [native selected-character stage](NATIVE-CHARACTER-STAGE.md) is now connected
to the production picker. Portrait-led roster rows load independently, while
the immediate shell owns input and retains acknowledged selection semantics.
The original record/server-info/player pages are created on demand. Keyboard
navigation owns the same original edit keys and advances from pending requests;
narrow views hide the optional stage to keep roster/actions in bounds.

The [last-seen appearance follow-up](NATIVE-CHARACTER-LAST-SEEN.md) supersedes
the earlier prototype-only status. Actual original-server vault replies omit
equipment; unknown gear now uses a portrait until an admitted controlled
appearance has been saved. The labeled cached model is verified before a second
Play with an owned vault-only server. Complete fresh reply data takes priority.
The production integration is implemented, while full visual/action acceptance
remains open. No automated public gameplay connection was used.
