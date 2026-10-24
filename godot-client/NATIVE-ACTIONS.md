# Native context actions and targeting — partial migration

Godot owns the native right-click wheel, mouse/key input, target state and
original cursor textures. The existing JS session remains the protocol owner.
This milestone does not complete combat, all radial actions, player windows,
NUI, animation cues or performance acceptance. Local testing only; no Arelith.

## Implemented boundary

`tools/action-service.mjs` reuses `networkRadialActions`,
`networkDefaultInteraction`, `prepareNetworkSpellMenus` and
`NetworkSpellTargeting`. Spell classes/levels, family children, innate powers,
feat trees, disabled entries and remaining uses come from existing providers
and replicated state. Native controls send a scoped menu ID and physical slot;
they cannot fabricate a spell or action binding. Every subtree/back operation
gets a new identity. Late icons and async preparation cannot overwrite a new
menu, retired area, connection or controlled actor.

The server receives typed spell/feat/innate/item/mode/script-target requests.
Default clicks reuse reaction-dependent attack/talk, door/transition, pickup
and use policy. Rejected targeting clicks remain targeting and do not become
walk requests. Explicitly unported window/action handlers produce a visible
unavailable message rather than claiming success. Target masks, versions,
validity and cursor policy reuse the existing source implementation.

`systems/server_radial.gd` uses native controls in CanvasLayer 100. It preserves
eight physical slots, deeper pages, back/cancel, 1–8 keys and press-point
ownership. WASD and middle orbit remain available; a click outside the circular
surface cancels the wheel and remains available to the world. Original icon
PNGs are decoded into fixed native texture rectangles, independently of wrapped
captions and yellow use counters. The backend's original GUI/cursor resource
loader is exposed only in isolated staging build v14. Proprietary image payloads
remain transient, not copied into authored project sources.

`server_targeting.gd` owns native hover/selection/cancel state with scoped
tokens, stale-hover rejection and bounded hover requests. `server_cursor.gd`
loads original numeric cursor IDs and original pressed pairs. Text-entry focus,
world retirement, new connections and shutdown reset cursor ownership. Pending
AoE metadata is delivered but native AoE drawing is not implemented here.

## Actual evidence

- `reports/action-ui-native-v5.json`: 8,000 authored native assertions pass,
  including 3,985 retained-source pixel/octant cases. This is not a fresh native
  binary oracle. Checks cover physical holes, disabled/zero-use entries,
  submenu depth, stale icons, input ownership, typed target routing, cursor
  pairing and the actual original mouse-press point used for physics picking.
- `reports/radial-layout-graphical-v4.json`: Vulkan test attaches delayed,
  authored tall icons to long captions and separate use counters. All eight
  buttons remain 88×72 for 90 frames; queue peak 8,192 bytes. Its captured
  output has no script or queue errors.
- Nine action-service, eight protocol and seven integration-evidence Node
  cases pass. Earlier retained source provider regressions remain recorded;
  authored spell-family checks expose Good/Evil/Law/Chaos and prohibit casting
  the parent. Full native spellbook drag/drop is still pending.
- `reports/native-radial-local-v5.json`: all **25 real local-server checks**
  pass against authored `GodotGameplay`. Native ray picking opens the wheel;
  Examine receives the real server description/colors/portrait, and Talk
  starts actual server dialogue. Reply/end/abort, custom token 77, script
  overhead prompts and chat feedback pass. Native class/level navigation
  casts prepared Light; the server's replicated uses fall **2 → 1**, and
  reopening the wheel displays the changed count. Original talk cursor reaches
  the native owner. Native exit 0, explicit disconnect, no native errors,
  renderer errors or diagnostics; queue peak 16,384 bytes.
- `native-radial-local-v5-gameplay.png` was visually inspected: actual native
  dialogue and examine coexist, server colors/tokens and portrait remain,
  reply hit areas and FPS HUD are visible. The v3 radial screenshot was also
  inspected for original icons and overlapping menu order. A small authored
  room's instantaneous FPS is not sustained full-scene acceptance.

Failed local v1/v2 remain retained: wrapping Button text plus expanding icons
overflowed Godot's GUI message queue during actual delayed icon updates. Simple
isolated icon layouts did not reproduce the complete live interaction. Fixed
pixel-aligned controls with independent image/caption rectangles removed that
live failure; the queue limit was not raised. v3 passed the interaction flow but
exposed two custom-cursor texture leaks at shutdown. Explicitly clearing Input's
cursor and its cache while RenderingServer is alive fixes v4/v5. Acceptance now
rejects GUI overflow, native errors and leaked RIDs even if probe checks pass.

## Remaining acceptance

The next [spellbook milestone](NATIVE-SPELLBOOK.md) adds native family drag/drop
and quickbars with real child casting/preparation evidence. Native AoE preview
drawing, full radial hover timers/keyboard variants,
small-viewport layout, drag/drop and quickbars, inventory/player windows,
unported action handlers, full combat result/cue/animation/projectile/effect/audio
presentation, script-target real-server cases, exact skinned/invisible portal
picking, full cursor hot spots and broad object/target/device coverage remain
open. The native spell-family test is authored policy/UI coverage, not proof
that every installed family is castable in a full native spellbook.

Full NUI, remaining model controllers/particles, all other migration ledger
features and sustained >=60 FPS on complete moving captured/local scenes remain
unaccepted. The main/dist working client remains unchanged. Verified checkpoints
contain authored sources only. Run the bounded actual test using
`join-local.ps1 -RadialSmoke -Report <unused-name>.json` with the owned server
on the authored `GodotGameplay` fixture; it closes its own client afterward.
