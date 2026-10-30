# Direct-native keyboard movement repair

Base-speed clarification: [NATIVE-BASE-SPEED.md](NATIVE-BASE-SPEED.md) traces
the original getter/setter and installed tables.4m/s is the ordinary stock PC
rate and the local fixture's rate; it is not a universal maximum or a measured
speed for the user's current server character.

2026-10-25. Scoped movement correction; full multiplayer/migration and sustained
frame-rate acceptance remain incomplete. All automated gameplay checks use owned
localhost Prelude. No public server connection or original-process modification.

## Regression and resulting behavior

The direct-native `native_keyboard.gd` had replaced the earlier keyboard owner
with a request-only implementation. It sent a drive request every500ms, used
the last replicated server position instead of the continuing native position,
and did not install a local movement plan or track drive sequence replies.
`network_motion.gd` already contained the finite movement/gait rules, but the
default entry never invoked their keyboard-preview path. Strafe could consequently
use path direction as forward facing; short server paths could finish before
the next request. Earlier live checks accepted displacement, not continuous
running/strafe correctness. The historical JS/adapter results in
`NATIVE-MOVEMENT.md` did not establish this newer direct-native behavior.

The current path is native Godot:

- `native_keyboard.gd` owns held keys, repeated key-downs, original250ms local
  preview /500ms ordinary wire refresh,250ms turn-only refresh, release/focus/
  lifetime cancellation and partial-path timer adjustment.
- `native_data/drive_preview.gd` implements the original finite-vector plan,
  run/walk/back/strafe animation choices, normalized diagonals, independent
  facing, bisection/angular slide search and received-waypoint connectivity.
- `native_render/live_world.gd` installs previews through the existing native
  motion owner using the current predicted position and actual server walk/run
  rates. It preserves replicated objects; no local gameplay authority or speed
  multiplier is introduced. Received paths connect from the displayed pose.
- `native_render/drive_collision.gd` reads active native catalogs/tables and
  original WOK/PWK/DWK. Geometry is independent of highlight/interactability.
  Non-interactable static scenery can still block movement. Door open states,
  other displayed creature radii and floor coverage participate. Reads prewarm
  in bounded batches ahead of the first keypress. CPU resource jobs are included
  in world-retirement ownership and drained on shutdown.
- `native_data/object_surface.gd` reads original ASCII PWK/DWK, including empty
  decorative resources and all three door states, on native asset workers.
  Prepared data uses the existing content-addressed external cache.
- The JS protocol hosts only encode requests and return scoped sequence replies.
  A local preview tick may advance the input sequence without sending a packet,
  as the original does. Sequence replies carry connection/generation/area/actor/
  lifetime/request ownership. Late replies after release, re-press or replacement
  cannot take over the newer hold. JS performs no rendering/collision planning.

Controls remain W/S forward/back, A/D turn, Q/E strafe, Shift walk. Normal forward
movement uses the server run rate; back and pure strafe retain their original
rates/animation rules. A menu does not suppress movement unless text is focused.

## Original evidence and adaptation boundaries

Target NWN:EE89.8193.37-17 x64, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original executable/install and Ghidra project remain unchanged.

| Original boundary | Validation / retained evidence |
|---|---|
|UI drive1406f1e40; input timing1406f1bc0 | `evidence/multiplayer-keyboard-input.md`, `evidence/multiplayer-keyboard-repeat.md`, `backups/animations/native-drive-input-timing-v1.json`; native250/500ms scheduling and partial-refresh distinction. |
|Finite-vector preview1406ea9e0; path installation1406ead5a | `scripts/inspect-native-drive-preview.py`, `backups/animations/native-drive-preview-v1.json`;90 original vector/animation cases and4 partial-line cases. |
|Mode2 path search1407fdeb0 | `backups/animations/native-drive-slide-v1.json`;118 cases with ordered captured lower collision answers, endpoints/factors, blocked cases and different rendered origins. Preserves native reciprocal-square-root normalization and near-unit threshold. |
|Received path1408001f0 | `backups/animations/native-path-acceptance-v1.json`;73 cases including matching/stale sequence gates, waypoint connection/retention and authoritative reset. Native height projection/notifications are lower boundaries, not exhaustively ported. |
|Drive request1407bf980 / server140452ec0; abort1407bf040 /140452ba0; turn1407c03b0 | Existing protocol codecs, real original-server integration and retained keyboard evidence. No protocol dialect change. |
|Client line1407e6a20, tile polygons14084f1f0, area polygons140297bd0, creatures140767740 | `evidence/multiplayer-client-drive-collision.md` documents the full original controller and its explicit lower providers. The new native footprint tests below are a conservative geometric adaptation, not execution/parity of every native polygon branch. |
|PWK1402ce0b0 / DWK1402cf720 readers | Existing `src/object_surface_mesh.js` and original reader observations used as reference only; stock original resources are read in place by the new native parser. No asset files are copied. |

**Remaining collision limits:** native line checks currently use triangle
coverage/capsule tests instead of the original AABB/adjacency/rectangle-scratch
implementation. Very unusual stacked geometry/contact can differ. Original
DM/control bypass storage and binary object walkmesh sections remain unported.
Unsupported collision data stays diagnostic and can suppress local preview;
wire requests and original server corrections remain authoritative. No invisible
wall footprint or fabricated route is substituted. This work does not claim
perfect prediction under every server latency, collision, shape or interruption.

## Verification

Normal-heap CDB, four exception traps, source hashes pinned during each run,
engine/lifetime-error scans. Results in `reports/`:

| Receipt | Coverage |
|---|---|
|native-drive-preview-v3 |1162checks: retained original vector/slide/acknowledgement observations; actual native driver/live-world preview; three-second continuous run12m,walk6m,pure strafe4.8m; zero stationary/idle frames on authored clear geometry; preserved strafe facing; normalized diagonals; late-ack/re-press protection and unchanged canonical inputs. |
|native-drive-collision-final-v1 |75checks: native floor/tile boundaries, rotated tile, wall sliding, actual non-interactable footprint, door-state changes, displayed creature circles,40 original installed PWKs and20 original DWKs. |
|native-drive-input-v1 |29existing native wire/focus/menu/lifetime, original WOK picking and camera checks. Local ticks are distinguished from actual wire packets. |
|native-session-drive-preview-v1 | Default launcher and original localhost Prelude: player ready, movement/UI/finish passed, scoped ack and native collision loaded. This early run exposed first-input pending collision reads, subsequently prewarmed. |
|native-drive-prelude-v1 | Actual Prelude run/turn and Q/E strafe with inventory open, real dialogue/examine/door transition and clean exit; Q0.931m,E0.974m in600ms,minimum facing dot1.0 for both. One first-frame stationary sample each; collision/wall/slide diagnostics retained. |
|native-drive-prelude-final-v1 | After prewarming and native received-path repair: two real Prelude door transitions and clean authoritative movement/UI/finish;8drive packets,13preview ticks,12accepted sequence replies;Q0.930m,E0.896m in600ms,minimum facing dot1.0. No pending-object blocks;7original collision models loaded. Old worlds/workers fully retired. |
|native-session-drive-reconnect-v1 | Default native launcher,2fresh original localhost connections; native controls/UI/movement/finish and source checks pass; collision models prewarmed, no pending objects. |

The final contact-adjacent strafe phases still contain3(Q)/1(E) stationary
samples out of72/77frames. These include first-frame ownership/order and wall
contact; exact attribution of each pause remains open. They are retained rather
than presented as zero-stutter real-world acceptance. The authored clear-path
simulation has zero stationary/idle frames, and original vector/slide/path
observations pass, but those are distinct from contact/server-latency coverage.

Pre-change authored-source backup: `backups/native-drive-before-v1.zip`, SHA256
`243d7ba23b771463bb45ca3c77d88c9f12e4e7d8431920c749b16d23e600554a`.
The first preview testv1 failed the slide comparisons; it revealed that generic
normalization differed from the original near-unit/reciprocal normalization,
and that the test needed each original case's separate rendered origin. Both
were corrected; failed evidence remains retained.
