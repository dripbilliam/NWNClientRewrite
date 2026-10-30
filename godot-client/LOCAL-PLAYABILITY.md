# Original campaign playability baseline

The user selected the original **Prelude** campaign on 2026-10-24. The owned
local server uses `127.0.0.1:5121`, the existing isolated
`runtime-logs/local-multiplayer-server` profile and the installed, unmodified
`nwserver.exe`. It replaces `GodotFeedback1` as the ordinary playability baseline.
No automated public game-server connections are authorized.

Prioritize a complete rendered and interactive campaign before further
performance experiments. Preserve original models/textures and established
gameplay behavior; the existing allowance for engine lighting differences holds.

## Acceptance route

1. Join the actual campaign and select a character; verify terrain, lighting,
   animated creatures, body parts, equipment and effects finish appearing.
2. Walk and use WASD around furniture, steer the camera with menus open, and
   interact with a creature, a door and a usable object.
3. Open inventory, character sheet and spellbook; equip an item and cast a
   usable spell, checking the authoritative result and visible animation/effect.
4. Start a campaign conversation, choose a reply and verify chat/feedback.
5. Change areas and return; save/disconnect/reconnect, checking character state,
   correct replacement content and retirement of old scenes/workers.

Record failures and missing presentation separately. The first direct-native
Prelude functional check now joins the real campaign, draws nine tiles and
twenty entities, follows a scripted authoritative 1.5-metre walk and retires
cleanly. The later `reports/native-prelude-world-v7.json` also restores original
tile lighting and native ground picking/click movement with no GPU geometry
readback. It rejects JS rendering dependencies at runtime. Native movement
simulation and original WOK height loading were connected afterwards and pass
headless checks across all five Prelude areas; live validation,
complete gameplay UI/input/effects, visibility and untested transitions leave
this acceptance route incomplete. See [current evidence](NATIVE-LIVE-RENDER.md).
`tools/test-native-local-world.ps1 -Run <unused-name>` repeats
that bounded local test, reading the existing local key privately; no public
server is contacted and the installed test character is not modified.
The direct entry now also wires raw chat/dialog/creature examine messages into
native TLK/color/portrait preparation and Godot controls. This addition passes
headless checks and still needs the campaign dialogue/examine route above;
Original font and NUI skin resources now prepare/bind natively; complete
item/token/NUI layout/other menu integration is pending. The latest localhost
attempt was rejected during key authentication before world loading; the
separate captured-world check passes with the original game preserved.

The ordinary `join-local.ps1`
multiplayer launcher still uses transitional JS resource/whole-area GLB
preparation. Its campaign behavior can provide a reference, but does not accept
the fully native rendering goal. `native-world.ps1` is an incomplete offline
static-world inspection entry, not this campaign test.

Focused scripted fixtures and offline captures remain useful regression tools.
Fixture harnesses restore Prelude afterwards. Their narrow passes are not a
substitute for the campaign route or complete migration acceptance.

## Server control

Run `./scripts/local-multiplayer-server.ps1 -Action Status` to inspect the owned
server. When stopped, start it with
`./scripts/local-multiplayer-server.ps1 -Action Start -Module Prelude`.
`./godot-client/join-local.ps1` opens the existing local multiplayer client.
Preserve unrelated user game/editor processes and campaign sessions.

## Native local gameplay milestone

NUI is deferred at the user's request. Compatibility with the original binary
and server rules is required; the installed server remains unmodified and
authoritative. `reports/native-prelude-world-v19.json` passes on localhost:

- Native original-WOK floor picking fixes movement clicks hitting the bedroom
  ceiling. The physics ray error is 0.000304 metres with no GPU mesh readback.
- Server replication confirms a 1.50003-metre click and 2.49008 metres of
  keyboard drive, including steering and release. Native camera follow remains
  centred on the controlled character. These scripted input-owner checks do
  not establish physical keyboard feel or latency tolerance.
- Both original NPCs receive examine/conversation requests. Original TLK text,
  chat and reply controls display server results. The fixture chooses offered
  dialogue replies, including Bim's tutorial skip; it executes no local scripts.
- The server opens the previously barred door and transfers us from `m0q1a`
  (nine tiles/20 entities) to `m0q1b` (100 tiles/92 entities). The new area
  renders with no pending batches, and CDB records a clean exit with no trapped
  exception or engine/lifetime error. Return trips/reconnects remain pending.

Earlier v16/v17 retained the barred door and displayed the server denial;
that was campaign progression, not permission to force the door open.
One unhandled feedback packet, 18/20, remains. Door visual animation, essential
inventory/spell/combat menus, effects, lighting/cutaway and other rendering
parity are incomplete. This is not full multiplayer or performance acceptance.

The separate user-provided local test credential is stored only as Windows
current-user DPAPI ciphertext in ignored runtime data. The client talks only
to the owned localhost game server; the original server retains its own
standard authentication service behavior. No public game-server connection
was made. The original game/editor are preserved; FPS is not benchmarked.

`play-native-local.ps1` adds an experimental interactive entry using the same
native rendering path and installed wizard test character. It stays open until
its game window closes. It is separate from the existing richer transitional
launcher and has no character-selection or full gameplay UI yet:

```powershell
./godot-client/play-native-local.ps1
# If preserving a known running original client for functional testing:
./godot-client/play-native-local.ps1 -PreserveOriginalPid <actual-pid>
```

The bounded test also accepts `-ProtectedKeyFile <DPAPI-file>`; no credential
goes in Node/Godot command arguments or reports. Its normal script is
`tools/test-native-local-world.ps1`. The interactive lifetime/manual-close mode
has not had a separate manual play acceptance.

`native-light-motion-v5.json` passes 83,222 headless checks, including 29 new
input/focus/lifetime, rotated floor-picking and camera checks. The current
milestone verifier is `node godot-client/tools/check-native-playability.mjs`.
Earlier `check-native-light-motion.mjs` remains a historical source-pinned
verifier for its prior milestone. Deferred `native_data/nui_state.gd` and
`nui_projector.gd` are unconnected WIP, not part of this acceptance.

## Native inventory milestone

`native-prelude-world-v21.json` extends the route with native inventory and
equipment. Eight actual server item IDs, names, dimensions, slots, counts,
gold/weight/capacity and AC display in the existing movable Godot inventory.
`I` opens/closes it; creature slots remain off by default. Native contextual
actions and drag/equipment controls send ordinary original-server requests.
Item abilities/targeting, stores, full inventory GUI skins/options and several
container paths still require migration or live acceptance.

`native_inventory.gd` owns that projection from raw replicated state. Item
requests never move an item locally; native stale-view/lifetime checks and the
protocol session/server validate identity and membership. Error notices remain
visible after refresh. `server_inventory.gd` now accepts a native Texture2D
without the older PNG/base64 route. The host import guard rejects JS item icon,
inventory layout and inventory service dependencies.

`native_item_icons.gd` renders the original GUI MDL/UVs in a private Godot
viewport, with original replacement bitmaps and PLT material colours. Both icon
metal channels use the original armor02 palette. Source decodes/palettes are
cached on disk; completed GPU icon textures are cached in the native owner and
reused after refresh/area change. There is no new JS icon renderer. Finished
viewport images are not yet persisted to disk. Animated custom GUI icon
templates are diagnosed rather than silently rendered in an incorrect pose.

The live test confirms server unequip to backpack and re-equip into slot2,
including native rendered-appearance replacement and restoration. It exercises
keyboard movement with inventory open, original conversations/door transition,
then reopens inventory with the same equipped ID in the next area. Eight icons
produce 10,127 nontransparent pixels; no new icon render is needed on reopen.
Both inventory screenshots were inspected. CDB is armed, sources are unchanged,
and engine/exception checks are clean. One existing 18/20 feedback packet remains
unhandled. This is a functional run with the user's original client/editor
preserved, not a clean FPS benchmark or full native binary parity.

`native-light-motion-v6.json` passes 83,829 headless checks. Its 607 inventory
checks include 192 original-table icon plans/resource selections, exact original
palette pixel hashes, direct texture binding, server-only transfer behavior,
default hidden creature slots, rejection feedback, stale area selection and
worker draining. Eleven existing native-reference Node inventory/icon tests
also pass with installed-resource access. No original assets were copied into
the workspace. The original retirement rollback remains the last fully accepted
checkpoint; the inventory archive is another verified WIP.
