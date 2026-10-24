# Native creature appearance and palette assets

Original creature appearance plans and PLT character textures now prepare in
Godot without JS rendering, Three, GLB conversion or image transfer. This is
the resource foundation for complete character assembly; it does not yet put
animated actors into the direct native campaign renderer.

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

Complete actor scene assembly, original skin/animation source decoding and
supermodel inheritance, held/worn equipment, ground items, controller/effect
behavior and live campaign integration remain work. The ordinary multiplayer
launcher still uses transitional JS preparation. The goal remains incomplete;
no full creature, campaign, stability or performance acceptance is claimed.
The playability baseline is [the live local Prelude campaign](LOCAL-PLAYABILITY.md).
