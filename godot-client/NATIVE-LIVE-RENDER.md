# Direct native multiplayer rendering follow-up

This is work in progress. The ordinary multiplayer launcher still uses the
transitional JS resource/whole-area GLB preparation. The separate bounded
`tools/test-native-local-world.ps1` entry uses Node for decoded protocol only;
Godot discovers, reads, decodes and publishes the original render resources.
No public connections are made by that test.

## Lighting and picking

`reports/native-prelude-world-v7.json` records a clean local Prelude run with
nine tiles, twenty entities, original equipment/skins, restored tile lights,
and a server-authoritative 1.5-metre walk. CDB was armed, sources were unchanged,
no trapped exception or engine/lifetime error occurred, and workers drained.
The earlier v6 screenshot was inspected: warm bedroom lighting and cyan/orange
room lights are restored. Black wall/roof backs and camera cutaway remain.

The missing lights were original tile main-light colors, not a reason to add
an invented ambient floor. Native `tile_lights.gd` applies physical LightColor
rows to the original model's `ml1`/`ml2` nodes. It preserves unchanged RGB light
state and performs the original changed-color radius/flags/priority writes.
The retained binary observations identify nwmain SHA
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`,
ProcessTilePart `1400cb890`, Scene::SetTileLights `1400d3e60`, and table loader
`1402b536c` (`backups/animations/native-tile-light-observations.json`).

Native picking reuses collision shapes constructed from original CPU-decoded
triangles. The v7 ground-ray check called the normal native world-action
callback, resulting in a real local-server walk: hit error 0.000229 metres,
zero GPU geometry readbacks. This was a scripted ray/callback test, not an OS
mouse click. Hover/Tab and default interaction routing are connected, but NPC,
door, pickup and portal behavior have not all been verified. Skin picking uses
rest triangles following part transforms; deformed-skin precision is pending.

## Native movement frame owner

The direct live path now consumes raw ordered protocol movement changes in
`network_motion.gd`. Full registry snapshots seed new objects once and cannot
restart an already advancing path. Native original appearance rows provide
model type and WALKDIST/RUNDIST for animation speed. Removal, recreated IDs,
duplicate revisions, closed owners and normal frame progression are covered
by the headless integration test.

`reports/native-light-motion-v2.json` passes 141 integration checks, 47,421
movement/facing/gait checks against retained original-binary observations,
1,322 tile-light checks, 33,081 original surface checks and compilation of the live native entry. The later v3 suite adds 1,025 native UI/text checks. All source
hashes were stable and engine logs were clean. The first isolated fixture run
had a locked-object cleanup error; its logs are retained. The corrected fixture
uses deferred retirement and drains before exit.

The movement integration was added **after** live v7. It has not yet passed a
live or GPU test. The subsequent captured-world preflight preserved the user's
running original client and refused the graphical test. Do not use v7 to claim
the newer movement integration is live-verified. Native WOK height is now
connected as described below; its live stairs/slopes check, WASD prediction
and complete combat animation ownership are pending.

## Native original collision heights

`tile_surface.gd` now decodes original ASCII WOK aabb-node collision vertices,
face/material order, node transforms, float32 snapping, normals and plane
constants. Its query selects the first containing walkable face, then the first
denied face; reference Z does not select a different floor. Exact tile quarter
turns and area elevation apply at query time. This follows the already mapped
LoadWalkMesh `1402c1020`, ComputeHeight `1402bc3d0`, PlaneHeightAtPoint
`14022de80`, and tile wrapper `1404fd9a0` in the same nwmain build above;
the existing reference and research links are retained in `src/tile_surface_mesh.js`.
This is a port of existing evidence, not a new complete collision decompilation.

The independent offline oracle reads all five original Prelude areas. Native
decoding agrees on exact float32 geometry/plane/material hashes for 74 WOKs
and 3,748 faces, including 27 nonzero node orientations. All 32,634 sampled
height queries agree within 1e-5 metres (observed maximum 4.45e-16). A native
movement test follows an authored elevated slope for 120 frames. General
original-CRT trigonometric bit parity is still unproven: the native decoder
uses Godot sin/cos rounded to float32 and explicitly bounds its angle input.

`terrain_surface.gd` loads WOKs and surfacemat on at most two native workers,
using the content-addressed original-source cache. The initial Prelude room
prepares six unique WOKs plus the table; a second owner reuses all seven cached
entries. Both owners drain their workers on close. The direct live renderer
waits for these original height resources before area admission and supplies
their query to the native movement frame owner. No collision geometry or
height array comes from JS. The first surface test emitted NUL-string warnings
from a fixture/format check; byte validation now precedes text conversion and
the corrected logs are clean. Earlier reports are retained.

WOK adjacency, AABB query acceleration, line clipping, door/placeable collision
and WASD prediction remain incomplete. The old nearest-render-triangle height
helper remains in the transitional launcher; it is not used by this new path.

## Native raw-protocol gameplay text and portraits

The direct native entry now forwards original decoded speech, conversation,
examine, custom-token and TLK-override messages without formatting them in JS.
`native_gameplay_ui.gd` owns their queued presentation and the existing Godot
chat, conversation and examine controls. UI clicks emit server reply IDs and
chat requests; the non-rendering protocol owner validates and sends them.
World clicks outside these menus retain the native picking path.

`talk_table.gd` reads original TLK records directly with bounds checks, explicit
Western byte decoding and a bounded requested-record cache. It does not read
the whole TLK into the runtime. Original rule tables and portrait texture data
prepare on at most two native workers using the persistent content cache.
ImageTexture publication occurs on the main thread. Portrait results are
checked against the current generation/target/revision; no PNG/base64 asset
transfer or browser image preparation occurs in this path.

`talk_text.gd` owns token scanning, the original CRC lookup and 16-byte table
hash boundary, custom tokens, TLK overrides and the currently supported named
token providers. `rich_text.gd` recognizes fixed-width NWN RGB controls before
token delimiters, preserves nested color stacks and produces literal Godot
text spans. Server text is not interpreted as HTML or BBCode.

`native-light-motion-v3.json` passes 82,990 headless checks. The 1,025 UI checks
cover 192 original TLK record hashes/lengths, 180 contextual token cases,
255 RGB-byte cases, malformed TLK bounds, raw message presentation, native chat
and reply controls, stale-generation rejection, original portrait loading and
worker cleanup. Engine logs are clean and source hashes are stable. The first
entry compilation exposed an inferred-type error; it was corrected and the
failed log is retained. Headless portrait binding is not GPU readback or a
live-server visual check.

The new UI path now binds original installed fonts through the native resource
owner described below. Original GUI model skins, complete item/trap examination,
additional named-token providers, notices and
feedback, inventory/spellbook/character/level-up/NUI and the other gameplay
menus remain incomplete here. English installed TLK paths are currently
selected; custom TLK/profile/Workshop/NWSync and broader encodings need native
mounting. The ordinary launcher retains its prior UI backend. Live validation
of all changes after v7 remains pending; no gameplay or frame-pacing acceptance
is implied by these headless checks.

## Native fonts and NUI skin resources

`ui_skin.gd` parses the installed NUI TOML subset directly. `font_data.gd`
validates original SFNT table storage on native workers before FontFile
publication. `native_ui_skin.gd` owns original skin/font/image preparation,
content-hash reuse and main-thread font/texture publication. Gameplay controls
inherit original `fnt_maintext` and `fnt_default` fonts. The original monospace
font and all skin textures are available through a direct native-resource
entry in the existing Godot NUI renderer. No FontFace/browser, PNG encoding,
base64 transfer, JS skin parsing or offscreen Three renderer is involved.

The original skin has 149 scalar values, two font specifications and 27 image
references. Preparation includes three distinct font files (the two skin
fonts plus the gameplay default). The cold owner has zero cache hits; the warm
owner reuses all 31 entries (skin, three fonts, 27 images). Resource replacement
preserves unrelated NUI resources. Worker/data preparation is bounded to two
concurrent jobs, and retirement drains them.

`native-light-motion-v4.json` passes 83,193 headless checks. The added 203 checks
cover the actual original skin scalars/font bytes, malformed SFNT bounds,
font shaping, native widget bindings, original image styles, cold/warm reuse,
resource replacement and cleanup. General font raster/settings fidelity is
not established by FontFile metrics. NUI layout/bindings/input projection and
base-game GUI model rasterization remain on the migration list. The first
entry compilation exposed a name collision with Godot's Skin class; the
corrected log and full suite are clean, and the failed log remains retained.

## Latest captured and local attempts

`native-capture-world-v9.json` and `.verification.json` pass the updated native
captured-world check: 48 tiles, 889 static objects, eight creatures, one ground
item, nine skin meshes, zero pending worker tasks, armed CDB, unchanged sources
and no trapped exception or engine/lifetime error. The screenshot was inspected;
wall/roof cutaway and effects are still incomplete. Preparation took 16,614 ms.
The 89 settled frame intervals had p95 5.176 ms and worst 5.46 ms, while loading
had one interval above 50 ms (56.683 ms). These are CPU wall-clock intervals
from an incomplete scene with another game/editor preserved, not GPU timings
or a clean 60 FPS acceptance. The captured entry does not exercise the new
gameplay UI and is not a full moving-network replay.

The local Prelude attempt `native-prelude-world-v8.json` failed before world
loading: BNVR connection error 16, with the owned server logging key-auth
rejection. Its temporary debugger process was confirmed absent afterwards.
The user's original game and editor were preserved. That failure is not a
rendering crash and provides no live verification of the new movement/UI path.
The runtime import guard now additionally rejects JS UI/text/skin preparation.
Successful future local checks must also observe prepared native UI resources.

## Remaining acceptance

The later **native local gameplay milestone** supersedes the login-blocked
status above: `native-prelude-world-v19.json` passes with the separate legitimate
local test key, preserving the original client and editor. Native WOK floor
picking, keyboard drive/stop, camera follow, both NPC examine/dialogue flows and
the original server's door transfer reach `m0q1b` (100 tiles/92 entities) after
`m0q1a` (nine tiles/20 entities). `native-light-motion-v5.json` passes 83,222
headless checks. Details, reproduction and explicit remaining gaps are in
[local playability](LOCAL-PLAYABILITY.md#native-local-gameplay-milestone).

The server's observed authenticated ACK-only frames during validation now get
transport replies without player admission or game-data delivery; explicit
BNVR acceptance remains mandatory. The local connection timeout is 45 seconds.
Eight focused peer/login tests pass; the sandboxed installation test is skipped.
The first succeeding retry also had a newly cached key, so causality between
keepalive handling and that success is not established. No auth bypass or
original-process change was made. Credentials remain DPAPI-protected/private.

The current verifier is `tools/check-native-playability.mjs`. It verifies
current source hashes, the local route and headless checks, and retains the
last fully accepted retirement backup. The new archive is a WIP playability
checkpoint, not full migration/performance/stability acceptance. Old captured
world source pins are historical after shared picking changes; the captured
world has not been rerun for this milestone. NUI layout/input work is deferred.

The normal launcher switch, native catalog profiles/Workshop/NWSync mounting,
full UI render resources and input, original effects/controllers/weather,
visibility/cutaway, complete native walkmesh collision, repeated transitions/reconnects,
captured moving-world regression and sustained frame-pacing checks remain.
Broader lighting parity and the historical native shutdown fault are unresolved.
Neither full multiplayer playability nor the 60 FPS goal is accepted here.

Run `tools/test-native-light-motion.ps1 -Run <unused-name>` for headless checks.
When graphical tests are available, run the bounded local test and the captured
world with `-InputDescriptor reports/native-capture-input-v2.json`, CDB capture
and normal heap. Preserve running user sessions and all earlier reports.
