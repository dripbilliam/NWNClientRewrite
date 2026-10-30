# Direct-native point, area and beam delivery

The default `join-native.ps1` client now routes original object visual packets,
extended P/B records and type-11 area visuals in Godot. Native workers resolve
the active resource tables and original models; JS forwards decoded messages
and source identity only. This is a scoped effects milestone, not complete
combat, projectile, rendering or mixed-client parity.

## Ownership and original behavior

`native_data/object_visual_route.gd` preserves normal/P/B/999 selection, source
and target admission, original body-part fields and duration rules. Normal
point records allocate the original `c_dummy` model. The reviewed source-role
status-zero abort is retained rather than normalized to the target-role branch.
`native_data/area_visual_definition.gd` selects a single original effect model,
including original quality, geometry priority and orientation fields.

`native_render/client_dummies.gd` owns private ascending IDs and lifetime tokens,
shared by dummy and area allocations. These never enter the authoritative
registry, interaction picking or collision. Original temporary-object fade/expiry
arithmetic retires dummy models and rigs; area effect retirement releases its
private allocation. Presentation time currently projects the local monotonic
clock; authoritative world-timer pause/synchronization is still open.

The native effect owner admits at most two prepared effects per frame and uses
bounded queues/assets. Scope/generation checks reject old worlds; canonical
lifetime checks reject reused source/target IDs. The beam endpoint is the
actual resolved physical target Part, traversed through the original reference
BFS. Its binding signature includes reference model publication/revision:
an asynchronously loaded child must trigger attachment again. Stable pose
updates do not repeatedly rebind. Missing Parts hide the beam rather than
guessing another endpoint. Detailed profiling includes `callback_dummies`
separately from effects/audio/reference owners.

These ports use the retained reviewed original-derived owners, not new runtime
binary observations. Original target SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Object-visual receiver: `1407857f0..14078644b`. Beam attach/start/stop:
`14096ba80`, `14096a110` type 7, `14096fa90` type 7. Reference BFS and controller
evidence remain in [native model references](NATIVE-REFERENCE-LIGHTNING.md) and
[native effect animation](NATIVE-EFFECT-ANIMATION.md). No original process or
binary was modified; original assets remain outside the authored workspace.

## Evidence

- `reports/native-point-effects-final-v1.json`: **228 checks**, 144 authored
  receiver cases and 42 area loader cases compared with the retained reviewed
  loaders. This is selection/callback parity, not actual network coverage of
  every branch.
- `reports/native-private-dummies-final-v1.json`: **12 checks** with the installed
  original `c_dummy`, actual native worker preparation/anchors, delay order,
  expiry, model/rig release, source abort, area allocation and nonreused IDs.
- `reports/native-beam-binding-v1.json`: **10 checks** using actual native
  runtime/BFS/reference owners and authored physical nodes. Late publication,
  stable/moving/replaced/missing/restored target Parts are exercised.
- `reports/native-point-beam-live-final-v1.json`: **24 checks** through the
  unchanged original localhost server on isolated port 5125. Authored server
  chat commands produce actual duration Darkness, instant Healing, a location
  area visual and a five-second lightning beam between distinct real creatures.
  Original resource draw/sound playback, endpoint identity/position, area
  allocation isolation and effect/host retirement are checked. The corrected
  v2 beam screenshot was visually inspected: the beam reaches the NPC.
- `reports/native-point-raw-events-v1.log`: **6 tests**, raw combat/visual packet
  cloning, scoped lifetimes, source replacement and type-11 forwarding. No
  presentation selection or dummy allocation occurs in transport.
- `reports/native-point-actions-regression-v1.json`: **62** existing real-server
  gameplay/menu/combat checks pass with the new effect ownership present.
- `reports/native-point-lifecycle-v1.json`: owned Prelude cancellation, abort
  during streaming, two reconnect cycles and stale-connection isolation pass;
  sources remain unchanged, no trapped native exception, no workers remain.

The native debugger runs pin their source and arm four normal-heap exception
traps. The live final run exits cleanly with zero workers remaining, unchanged
source and zero public connections. Functional timings are not clean GPU
benchmarks and do not establish native-binary FPS parity.

The initial beam v1 pixel test passed despite its endpoint being wrong. Visual
review exposed the missing late-reference reattachment; v2 and final runs add
an actual target-Part endpoint assertion. Keep v1 as failure evidence rather
than using its passing pixel count as proof of beam parity.

## Still open

Traveling spell/ranged projectiles are a distinct receiver, path/AI and impact
system. The later [native projectile milestone](NATIVE-PROJECTILES.md) adds
server-timed homing spell flight; full ranged/specialized parity remains open.
Normal point-dummy packets
have authored routing and real model-owner tests; the location fixture exercises
type-11 area packets, not that separate wire branch. Several program types,
nonidentity visual controllers, broader body-part/shape/door/area transitions,
camera shake, wind/collision, pause synchronization and mixed native-client
acceptance remain open. Particles remain off by default; the visual fixture
temporarily enables them in memory and restores the user's setting.

Before checkpoint: `backups/native-point-effects-before-v1.zip`.
Verified after checkpoint: `backups/native-point-area-beam-after-v1.zip`,
SHA256 `c40f80913dbba22bb50a59c4b083a591d95aceffd0154c8d04960eec4464f221`.
The active completion requirements remain in [the base gameplay goal](BASE-GAMEPLAY-GOAL.md).
