# Native status HUD

The existing JS effect-bar core now has a native Godot counterpart. This is a
multiplayer UI milestone; party portraits/actions and the rest of the player
HUD remain separate migration work. The original client remains intact.

## Data and presentation

`tools/buff-bar-service.mjs` reuses `networkEffectIcons` and the original
`effecticons.2da` StrRef/Icon metadata. Original icon images are decoded through
the existing staging provider and delivered to `systems/server_buffs.gd`.
Localized labels use the existing server-aware text resolver. No original
assets are copied into project source or reports; reports keep resource names
and image hashes only.

Both wire states **0 and 1** represent a present icon. Only explicit removal
from the server's aggregate clears a slot. The bar does not invent durations,
countdowns, spell stacks or gameplay effects. IDs are sorted and remain raw
server IDs. Unknown metadata retains the existing generic label/placeholder.

The bar uses 36-pixel buttons with the original 32-pixel images, wraps beside
the reserved party area, and scrolls within a bounded height. Tooltips support
hover, focus and click pinning, with a dark background and text shadow.
Outside clicks and Escape dismiss them; outside clicks still reach the world.
Tooltip drawing stays below the radial layer. Buttons issue no gameplay
request. The connection-menu shortcut moved to the lower right to avoid
covering status icons.

Views are connection/controlled-actor owned rather than area owned. Labels and
images are guarded against old views, actor replacement, token-string revision
changes and retired connections. Description work runs at most four jobs at a
time; view rows are delivered in bounded batches. Connection reset releases
widgets/images and partially staged views. Area replacement preserves the HUD.

## Verification

- `reports/native-buff-local-v2.json`: **17 +18 actual native status checks**
  over connections 1 and 3. Original Damage Resistance/Regenerating icon art and
  localized labels, GUI pinning, MMB rotation, actual WASD, outside GUI
  click-to-move, server expiry, and A–B–A pass in both sessions. Six area
  admissions have rendered/animated presentations; retired world owners are
  zero. Native exit 0, no engine errors, disconnected and zero pending status
  description jobs. The second-session screenshot was visually reviewed.
- Actual incoming player-state records include both additions, a state-1
  update that remains present, and the later explicit short-icon removal.
  Native final rows independently match the server's canonical aggregate.
- Saved-character reconnect reads back the exact saved disconnect bytes;
  all three exports retain one temporary regression-vault identity. Previous
  native status buttons/textures are gone, and the old backend drains cleanly.
- `reports/buff-ui-native-v3.json`: 17 authored native GUI checks, including
  real cross-layer connection-menu/status clicks, pinned-owner switching,
  stale descriptions/images, outside input, 400-entry scrolling, narrow
  viewport wrapping and weak-reference cleanup. Engine log is clean.
- `reports/native-buff-node-regression-v1.log`: 66 passing Node checks,
  including original effect-bar semantics, owner/async guards, bounded work,
  independent server-evidence acceptance, and the existing NUI regressions.
- `buff-lobby-native-regression-v1.json` retains 14 native lobby checks;
  `buff-nui-ui-regression-v1.json` retains 15 NUI checks. Logs are clean.

The first live attempt is retained as rejected. The connection-menu shortcut
overlaid the surviving icon, so clicking it opened the lobby and blocked the
following world click. The corrected overlay position and a combined native
UI regression address the actual conflict. The probe also waits for the
completed layout frame after removal before clicking a newly placed slot.

`tools/create-buff-server.mjs` builds only the authored `GodotBuffs1` local
fixture from the hashed navigation fixture. It uses the installed script API's
EffectIcon/ApplyEffectToObject signatures/constants to apply temporary icon
effects lasting 8 and 120 seconds. This tests native server icon replication
and expiry, not damage resistance/regeneration mechanics. Fixture hash:
`4ca09495e6a6f39602061ced22c5088ad17598738f5b2a2af430cbc4dcc0b5cc`.

With that owned fixture running, `join-local.ps1 -AutoPlay -BuffPreview` opens a
local preview and sends its authored `-native-buffs-start` command once.
Ordinary startup does not create effects. No Arelith connection is made.

## Remaining coverage

Broader effect/icon catalogs and server custom resources, forced pending-work
disconnects, physical input/device review, original font/skin fidelity and
large-list performance remain unaccepted. The authored 400-entry layout is
functional coverage, not a performance benchmark. The full party/player HUD,
native settings/workshop/debug UI, rendering/combat parity and sustained moving
scene 60 FPS goal remain incomplete.
