# Native local multiplayer bridge

Run from the workspace root:

```powershell
.\godot-client\join-local.ps1
```

The launcher preserves existing games and unrelated servers. It starts the
owned local Prelude profile when absent, verifies UDP 5121 belongs to that
profile, and pins its logged server public identity. It uses the existing
Windows-protected CD key without putting the key in command arguments, the
Godot process, files, or reports. The native multiplayer menu waits for the
user to connect, preview/select a character, and click Play. Installed and
application-vault characters appear only if local characters are permitted;
server characters retain their advertised source/reference/list generation.
The automatic visual regression chooses `wizard.bic` through that same UI.
Server-requested transfers now use the native ownership/adoption path within
the current session's address policy; the local launcher still restricts
connections to localhost by default. Public browsing remains a separate opt-in
launcher. See [NATIVE-HANDOFF-ENABLED.md](NATIVE-HANDOFF-ENABLED.md) for the local
evidence and remaining public-server limits. The owned server stays open after
the client closes. The exact
workspace project editor may remain open for functional checks; existing game
clients and unrelated editors are preserved and still block this launcher.

The established Node/Electron network session remains the protocol owner.
A hidden isolated resource-staging build prepares the actual joined area,
exports its original geometry/UVs/textures to an external temporary bundle,
then stops its Three animation/render loop. Godot imports the bundle and
owns native drawing, camera, picking, menus and per-frame object interpolation.
This is a transitional asset loader, not a Godot web export. Login/resource
admission and the native area import are separate states; the native scene's
area generation and mesh/hash acknowledgement must match the live session.

The bridge binds an ephemeral TCP port only on 127.0.0.1, accepts one local
client, authenticates a random one-use ticket from the user's temporary
directory, deletes that ticket after use, and bounds framed JSON messages.
The ticket is not a CD key. Inputs carry the area ID and generation; stale
inputs and unknown commands fail. A separate connection epoch also prevents
old input from being accepted when a reconnect reuses the same area ID and
area generation. NWN server scripts and navigation remain
server-owned. Area changes trigger another real-area staging/import cycle,
clearing the old native world and disabling its inputs during loading.

Controls:

- Click ground: server navigation request; click an eligible object: interaction.
- W/S: forward/back; A/D: turn; Q/E: strafe; Shift: walk. Native prediction,
  original drive timing and reused exact collision are described in
  [NATIVE-MOVEMENT.md](NATIVE-MOVEMENT.md).
- Middle drag / wheel: orbit / zoom, including with menus open.
- Enter: focus chat; Enter again: send through the real server.
- Right click: original context-action wheel, with native icons and deeper spell/
  feat menus. Click an action or use 1–8; center/Backspace goes back, Esc cancels.
  I: server examination. Hold Tab: highlights. Ctrl+Alt+F1/F2/F3: native panels/FPS.
- B: native known/prepared spellbook. Select a family to expose its variants;
  drag a leaf to a shortcut or a compatible preparation slot. F1–F12: shortcuts;
  Shift/Ctrl temporarily selects pages two/three. See
  [NATIVE-SPELLBOOK.md](NATIVE-SPELLBOOK.md) for real local evidence and limits.
- Server conversations use a native movable panel and server-provided reply IDs.
- Native colored chat, dialogue, examination/portraits and script prompts now
  have real local-server evidence; see [NATIVE-GAMEPLAY-TEXT.md](NATIVE-GAMEPLAY-TEXT.md).
- Native radial actions and typed targeting now have scoped ownership and an
  actual local Light cast/replicated-use check; see [NATIVE-ACTIONS.md](NATIVE-ACTIONS.md).
- Multiplayer: connect, inspect/select and play, export, or disconnect/reconnect.
  Save on disconnect and window close defaults on; a failed export leaves the
  native window/session open so the user can retry or explicitly disable saving.

The original models and textures are transferred without substitute assets.
Native creature articulation and GPU skinning now consume the original model
hierarchy, clips, weights and inverse references. Body/robe locomotion and
independent held scale are validated; see [NATIVE-MODELS.md](NATIVE-MODELS.md).
Native timed combat/cast playback and original hit events now have actual local
GPU-deformation evidence; see [NATIVE-COMBAT.md](NATIVE-COMBAT.md). Particles
remain frozen. Broader events, material/light/emitter controllers, full combat
effects/audio, exact blends and animated skin picking remain incomplete.
New spawns and changed equipment/shape are locally verified; see
[NATIVE-WORLD-LIFECYCLE.md](NATIVE-WORLD-LIFECYCLE.md). Doors' animated geometry,
effects, audio, combat presentation, inventory, spellbook, NUI, character
creation and full menu parity remain incomplete. Character selection is a functional native
list/record view; portrait/class-name/creation presentation is still incomplete.

`join-local.ps1 -AutoPlay` connects the installed wizard to the owned local
server through the normal native selector requests, then leaves the game open.
It runs no smoke inputs, screenshots or automated shutdown. The native FPS
overlay starts visible; F3 toggles it. This is an interactive preview, not a
controlled performance result.
Server-vault selection is implemented and covered by coordinator fixtures,
but a real server-vault-only admission test remains pending. Current-area removals are hidden, and
area changes rebuild the complete transferred scene. Engine lighting/fog and
material appearance still differ. This is a real multiplayer integration
milestone, not full gameplay or performance acceptance.

Validation (retained reports, no public-server access):

- `reports/local-join-v2.json`: real NWN admission, character confirmed, Prelude
  `m0q1a`, 375 meshes imported, native SHA/area acknowledgement, chat round trip,
  server-confirmed 1.5 metre movement, and explicit clean network disconnect.
- `reports/local-join-v3.json` / `.png`: additionally verifies the native
  controlled entity actually moves and the camera follows it. A native Vulkan
  screenshot shows the joined local area and returned chat. Renderer errors: zero.
- 12 Node checks pass: existing asset identity/blending/transfer regressions
  plus fragmented UTF-8 framing, coalesced records, invalid/oversized frames,
  unsigned object IDs, stale generation rejection and bounded input.
- The existing 23 authored native systems checks still pass:
  `reports/systems-local-regression-v2.json`.
- Native selector tests: 13 coordinator cases plus 14 native Godot UI checks
  cover policy, preview/upload buffer wiping, server references, old connection
  callbacks, duplicate Play, save failure/retry and scoped input. Native report:
  `reports/character-lobby-authored-v2.json`.
- `reports/native-lobby-local-v2.json` / `.png`: native selector requests,
  actual local admission, 375 native meshes, returned chat, 1.5 metre server
  movement, native rendered movement/camera follow, and graceful native exit 0.
- `reports/native-lobby-lifecycle-v1.json` and `-c1.png` / `-c3.png`: exports the
  first character into a separate external temporary vault, saves on disconnect,
  reconnects and selects that saved BIC, repeats movement/chat in native Godot,
  then invokes the close handler and saves again. Both connections load the real
  375-mesh Prelude area. Three persisted versions share one vault-entry ID.
  The user's application character vault is not modified by this regression.
  Native exit 0, explicit network disconnect, zero renderer errors.
- `reports/native-lobby-lifecycle-v2.json` adds explicit read-back hashes:
  both preview and upload on connection 3 read the vault BIC hash written by
  connection 1's disconnect export. The full lifecycle passes, including three
  versions of one saved entry, two 375-mesh native area loads, both native
  movement/camera screenshots, and native exit 0. This proves the reconnect
  used the exported BIC rather than silently choosing the installed wizard.
- The first selector live check caught a wrong close-handler property owner;
  its failure remains in `reports/native-lobby-local-v1.json`. It is not a pass.

For a bounded real native-server check with a new report name:

```powershell
.\godot-client\join-local.ps1 -Smoke -Report local-check-unique.json
```

This sends one local test chat line and a nearby walk request from Godot,
requires the server response and native rendered/camera movement, writes a
screenshot, then disconnects. Reports refuse overwrite. No FPS claim follows
from this functional check. A headless native run is insufficient to validate
its required screenshot and should not be used for this visual smoke.

Rebuild the isolated staging bundle only after modifying its transform:

```powershell
node godot-client/tools/build-local-bridge.mjs --version=v9
```

Choose a fresh version; existing builds are preserved. Normal `src/main.js`
and the working production `dist` are unchanged by this build.

The installed/saved character lifecycle regression is:

```powershell
.\godot-client\join-local.ps1 -LifecycleSmoke -Report lifecycle-unique.json
```

It uses a dedicated external temporary vault and the real owned local server.
It deliberately makes no animation, server-vault-only admission, or FPS claim.

Same-area spawn and original model replacement now have a separate actual-server
regression: `join-local.ps1 -ContentSmoke -Report <unused-name.json>` against the
authored `GodotLifecycle` module. See
[NATIVE-WORLD-LIFECYCLE.md](NATIVE-WORLD-LIFECYCLE.md) for the fixture setup,
native evidence, current server module and loading limitations. This does not
complete area-transition, metadata/controller or full gameplay acceptance.

Real A–B–A, stale pending-content rejection, native owner release and a new
saved-character reconnect now pass on the scope-aware build; see
[NATIVE-AREA-TRANSITIONS.md](NATIVE-AREA-TRANSITIONS.md). The final server is
restored to Prelude. Metadata/controller, cross-server and full gameplay
acceptance remain incomplete.

The native client now uses original drive/stop/turn packets and native per-frame
path prediction, facing and gait, with the existing exact collision planner
reused as a scoped service. W/S forward/back, A/D turn, Q/E strafe and Shift
walk follow the original mapping. [NATIVE-MOVEMENT.md](NATIVE-MOVEMENT.md) records
the retained-oracle checks, real chest-slide/menu/text-focus check, and renewed
area/reconnect validation. Broader feel/latency and complete gameplay remain open.
