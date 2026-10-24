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

Record failures and missing presentation separately. This route is pending for
the **direct native original-resource** renderer. The ordinary `join-local.ps1`
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
