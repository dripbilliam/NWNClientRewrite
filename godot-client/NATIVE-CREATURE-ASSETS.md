# Native creature appearance and palette assets

Original creature appearance plans, PLT character textures, original clips and
binary/ASCII skins now prepare in Godot without JS rendering, Three, GLB
conversion or image transfer. Direct actor assembly includes body parts,
robes, held/worn equipment and ground items. Broader controller, appearance,
attachment and effect fidelity is still incomplete.

## Current actor and live campaign follow-up

`actor_model.gd` retains original binary controller storage, transform keys,
events, skin arrays and physical node identity; ASCII named influences derive
rigid inverse binds without inheriting scale. Native workers resolve the
supermodel chain, preserve own-clip precedence and inherited animation scale,
and cache converted native rig data by the actual dependency content hashes.
Non-transform controller behavior is retained/deferred, not claimed complete.

Native rig assets request lazy Animation resources. A focused original
multipart-character check reduced main-thread installation from 854 ms to
30 ms. Its total elapsed time increased from 6.384 to 8.297 seconds; this is
not a loading-speed or FPS acceptance. See
`reports/native-actor-publication-comparison-v1.json`. The mature authored
animation/Bezier/sparse-skin regression passes 65 checks after the refactor.

`native-actor-data-v5.json` passes 266,819 checks across thirteen original
models, original binary skin arrays and 3,263 inherited clips. ASCII named
weights and derived bind poses agree with an independent text/hierarchy
reference. This does not establish every original ASCII compiler behavior.

`native-capture-world-v7.json` renders all 48 tiles, 889 static objects, eight
creatures and one ground item with nine skin meshes and no preparation errors.
The earlier frozen supplement supplies the missing original item texture;
no network fallback or invented texture is used. Initial frame samples and
publication times are retained; effects and complete playability are pending.

`native-prelude-world-v5.json` proves the first live original Prelude room:
nine tiles, twenty entities, actual player replication and a 1.5-metre walk
observed by both the server and native scene. The protocol process rejects
Three, Electron and model/scene preparation imports. Godot discovers and reads
the installed KEY/BIF/Prelude archive and prepares all displayed resources.
Native scene owners discard stale appearance results and retain authoritative
pose updates without rebuilding unchanged models. CDB exception capture,
unchanged sources, engine/lifetime checks and clean retirement pass.

The first screenshot was too dark. Follow-up v7 restores the original tile
main lights and verifies native ground picking/click movement. Native path
simulation was connected after v7 and is headless-tested; live validation and
camera occlusion still need work. Gameplay UI, complete interaction, effects
and transition/reconnect integration remain pending. See
[current scoped evidence](NATIVE-LIVE-RENDER.md).
No complete actor, campaign, stability or performance acceptance is claimed.
The previous CDB default-debug-heap stall and historical native AV remain
recorded; a clean normal-heap functional exit does not resolve the old fault.

Earlier palette-only stage evidence below is historical and has narrower scope.

`creature_appearance.gd` consumes raw replicated appearance/equipment fields and
physical original 2DA rows. It selects body/head models, fallback and PLT
candidate order, CAPart anchors, robe hide columns, six per-part material
overrides, and tail/wing models with cloak hiding and original scale values.
Its output remains native data used by the native scene owner.

`palette_texture.gd` reads original PLTs and the original palette TGAs. Both
retain file row order; palette row zero is original TGA row zero. It preserves
all RGBA components, ten layer selections and original UV orientation. Native
worker jobs own deep copies of their requested colors and candidate lists.
A present corrupt asset fails instead of falling through to another palette.

The persistent palette cache includes the actual PLT digest, all used palette
digests and color rows. GPU texture/material identities include that prepared
identity. Different character colors share geometry without sharing a mutable
palette texture. Runtime prepared data stays outside the workspace.

## Evidence

- `native-creature-data-v4.json`: **90 checks** pass for nine original captured
  appearances, 12 original PLT color variants, exact oracle pixel hashes,
  persistent cache read-back, malformed/missing inputs and actual background
  model/palette preparation after caller mutation of queued options.
- `native-creature-parts-render-v1.json` and `.debugger.json`: **18 native GPU
  checks** pass. Original `pfd0_head012` geometry renders with two original
  palette selections, one shared mesh and two independent textures/materials.
  GPU image read-back matches the exact prepared pixels. Owner retirement,
  debugger arming, unchanged sources and clean exit pass. The screenshot was
  inspected. This is a body-part drawing check, not a complete creature scene.
- Existing native archive/worker tests pass **80 checks** in `native-data-v8`;
  installed original resource/model tests pass **199** in
  `native-installed-model-v6`.
- `native-capture-world-v5.json` and `.verification.json`: the same native
  **48 terrain / 889 static object** room still prepares, renders 90 frames and
  retires with no trapped exception or engine/lifetime error. Eight actors and
  one ground item remain deferred in that entry.

V1/V2 creature-data failures are retained. They exposed an extra male-human
fallback in female head palette candidates; the corrected original order
matches all nine oracle appearances. V3 passed 89 checks; V4 adds direct proof
that queued options are isolated from caller mutation.

## Remaining integration

Broader controller/effect/appearance behavior and full campaign integration
remain work. The ordinary multiplayer launcher still uses transitional JS
preparation; the new protocol-only local entry does not yet replace its UI and
input. The goal remains incomplete; no full creature, campaign, stability or
performance acceptance is claimed.
The playability baseline is [the live local Prelude campaign](LOCAL-PLAYABILITY.md).
