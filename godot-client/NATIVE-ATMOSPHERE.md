# Native area atmosphere — partial, locally verified

The native client now receives the decoded area's sun/moon ambient, diffuse and
fog colors, fog amounts, directions, shadow gates/opacity, day/night flags,
FogClipDist, skybox flag, module period and transition timing. Godot owns the
ongoing color phase, fog range and camera far plane. The bridge no longer leaves
the native view on a constant black background or chooses sunlight merely
because the area's daytime colors are nonzero. Existing exported area sunlight
is explicitly tagged and reused; local model lights stay independent. Original
models, textures and UVs are unchanged.

This is a partial rendering milestone, not complete atmosphere, multiplayer or
performance acceptance. Testing used authored offline inputs and the owned
localhost server only. No online game-server connections were made after the
user's restriction. The editor was preserved and ordinary GodotFeedback1 was
restored after the temporary test module.

## Original observations and numeric verification

Target NWN:EE89.8193.37-17 SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
`reports/native-atmosphere-methods-v1.json` retains focused read-only REA
dossiers. Original binaries, running processes and the Ghidra database were
not modified. Synthetic original-code execution uses explicit lower boundaries;
it does not execute the original renderer or claim whole-function parity where
the caller block is bounded.

- Module update1407cffc0, range block1407d0197..1407d029b: end is FogClipDist,
  guarded to near+.01; start is (camera behavior distance-fog amount)+10,
  guarded to end-1.01. Negative starts survive. Far is max(end,45), plus90
  when sky is enabled and area skybox is nonzero. Camera getter evidence is in
  `reports/native-fog-camera-getters-v1.json`.
- Fog override1407e5850 assigns the same RGB to fog and scene clear color.
- Period dispatcher1407cfbb0 selects fixed day/night or starts dawn/dusk.
  Period3 is dawn (flag2ac), period4 dusk (flag2b0). Elapsed starts from native
  transition milliseconds; duration is minutesPerHour*60 seconds.
- Fixed setters1407e5390/1407e55f0 select sun/moon. A fixed-night area ignores
  module daytime. Transition1407e90b0 blends ambient/diffuse/fog and amount,
  fades diffuse to zero at midpoint while adding half to ambient, changes the
  day/night direction at halfway, and fades shadow alpha in global14128ec14.
  Fog amount is integer-truncated at the original boundary.
- Direction helper1407e5d10 positions the original light along the transmitted
  native vector. The native owner converts Z-up to Godot Y-up without inventing
  a direction when older packets omit one.

`tools/native-fog-range-oracle.py` executes 1,200 original range cases, and
`tools/native-atmosphere-oracle.py` executes 112 fixed/transition cases.
`tests/area_environment_state_test.gd` compares **6,468 exact float32/flag
observations**, all passing in `reports/atmosphere-state-v3.json`. Fixtures
record exact IEEE bits, avoiding JSON decimal-to-double comparison artifacts.
Coverage includes degenerate clips, negative starts, sky flags, midpoint,
negative and completed progress, durations and shadow percentages.

## Native and real-server checks

`reports/atmosphere-native-v2.json`: **23 passing Vulkan checks** through the
actual room loader and native owner. Checks cover tagged sun reuse, day/night
colors/background, direction/shadow properties, cached fixed colors, zoom fog,
server elapsed time, native-frame transition completion, fixed-night behavior,
stale/incomplete state rejection, negative starts, sky far range and cleanup.
Day/night PNGs were inspected. Fixtures are authored plane/box/region geometry.

`tools/create-atmosphere-server.mjs` derives authored GodotAtmos1 from the
hash-checked GodotPortal1 fixture, changing the ARE lighting fields to daylight
in A and fixed night in B. Module SHA256:
`341839e951100b1b6b511901188b114dc8c3aeee478a87c61d9831ef22227e45`.
No original art is bundled; installed original resources resolve normally.

`reports/atmosphere-portals-local-v2.json`: actual native mouse-triggered
**A-B-A**, three animated admissions, **14 passing portal checks**, two normal
interaction submissions and zero surviving retired owners. Three received
environment acknowledgements show day/night/day with the authored distinct fog
colors/amounts, matching each generation. Screenshots were inspected. Successful
shutdown disconnected the session and exited the native process cleanly.
Verbose Vulkan overlay naming/registry warnings are retained; no game script
errors, rejected commands or leaks occurred. This is a functional test, not an
FPS benchmark; transient screenshot FPS counters are not accepted measurements.

`reports/atmosphere-local-v1.json`: ordinary GodotFeedback1 animated movement
plus **16 passing dialogue/examine checks**, with native atmosphere applied,
no renderer/script errors, disconnection and native exit0. Backend checks are
retained in `reports/native-atmosphere-backend-v4.log` (32 passing tests,
including rejection of incomplete/stale/failing acceptance evidence).

## Ownership and limits

EnvironmentDelivery publishes only after the exact connection/area/generation/
transfer ticket is admitted. It accounts for time spent preparing the scene,
does not rewind on hour-only updates, and rejects retired connections/areas.
Godot validates required state and monotonic revisions. The whole owner is
released with its world; there is no renderer-bridge call per native frame.
Fixed color state is cached; zoom changes update fog locally.

Godot's stock depth fog uses **smoothstep of radial distance**, not the original
GL linear fog equation. Density1, curve1, no height/aerial/sun scatter are
explicitly configured. This is a documented engine approximation, not exact
GPU fog parity. Source: Godot4.7
[forward clustered shader](https://raw.githubusercontent.com/godotengine/godot/4.7-stable/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl)
`fog_process`, depth branch. Native range arithmetic is exact; Godot lighting,
tone response and shadow maps remain engine implementations.

Still pending: scripted area-light/fog update messages and gradual overrides,
pause/timing integration, skybox resources/animations and sky-visibility option,
weather/lightning/precipitation and their particle fog, tile-color/animation
policy, original shadow/culling/keyhole behavior and moving-scene benchmarks.
Cross-server handoff and other migration checklist gaps also remain open.

## Retained failures

`atmosphere-range-v1` compared decoded JSON decimal doubles and reported 160
last-bit decimal differences; exact float32 storage comparison fixes the test.
`atmosphere-state-v1` stopped on a bool/int test comparison (no report); its
identified headless processes were closed and corrected tests pass. Oraclev1
had reversed authored dawn/dusk labels; v2 corrects them, v3 adds exact original
shadow alpha and correct raw flag names. These older files are not acceptance.
`atmosphere-native-v1` failed a test-only GDScript inferred type; v2 passes.
`atmosphere-portals-local-v1` hit a polygon center covered by the movable chat
window, correctly blocking the click. The probe now searches real polygon faces
for an unobscured point; it still uses ordinary picking and menu guards. V2
passes. Failed artifacts are retained without being promoted.
