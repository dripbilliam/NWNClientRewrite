# Native effect animation runs and controller fields

The isolated v24 client now uses Godot-owned native run/controller playback for
private effect models that retain binary controller storage. This replaces the
temporary single-clip profile for those resources. Decoded-only models still
use the explicit fallback. This milestone does not complete effect parity.

## Implemented path

`systems/model_runs.gd` ports the reviewed original-derived playback owner and
run clock: physical run identity/order, reuse, current/stop/clear commands,
queue flags, reverse initialization, terminal-frame delay, loop overshoot,
transition weights, ordered events and periodic counter arithmetic.

`systems/model_controllers.gd` ports scalar/vector/quaternion sampling,
binary32 blend grouping and physical-ID hierarchy traversal. Bezier tails,
WORD indexing rules, quaternion sign changes/nonunit cases, duplicate IDs,
manual gates, the shared depth cutoff and live controller-count mutation remain
explicit rather than being delegated to AnimationPlayer blending.

`tools/export-native-animation.mjs` transfers retained original controller/value
records and physical hierarchy into the existing external private-resource
bundle. It does not invent binary records for decoded-only models. Canonical
creature export/playback stays on the existing path until a separate acceptance.

`systems/model_native_animation.gd` and `model_native_pose.gd` connect runs to
private native parts. Ordered runs write persistent binary32 fields; omitted
controllers retain prior state. Fields drive native local P/Q/scale, instance
mesh alpha/self-illumination and sampled emitter properties. Workers receive
the blended emitter fields rather than resampling only one clip. Manual part
placement survives lazy initialization and later animation while descendants
continue. Materials are private to each animated instance. Retirement clears
runs and breaks provider/entry references; a WeakRef test proves destruction.

## Evidence

All original observations below were recorded previously from target SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No new binary profiling or process modification occurred. Source owners are
`src/model_playback.js`, `model_run_clock.js`, `model_controller_sample.js`,
`model_controller_apply.js` and `model_animation_hierarchy.js`. Their reviewed
entries are PlayAnimation 140052580; run stage 14004e455; scalar 1400512c0;
quaternion 140051530; vector 140051750; generic control 140051c50; hierarchy
14004fe90; Bezier 14022ce00; quaternion interpolation 140231cd0. Lower scene,
allocation, specialized control and math-library services remain distinct.

- `reports/model-runs-native-v4.json`: 5,296 assertions replaying 2,173 original
  playback cases and 474 original clock profiles; exact callback order and run
  fields match. The dedicated engine log is clean.
- `reports/model-controllers-native-v2.json`: 3,301 assertions across 720 scalar,
  1,152 vector, 432 quaternion, 480 generic-control and 512 hierarchy cases.
  Exact numerical results and callbacks match, with no tolerance. Math-library
  agreement on these finite cases does not prove arbitrary native CRT parity.
- Inputs and expectations are encoded as exact binary64 hex in the oracle
  generators, avoiding Godot decimal-JSON perturbation. Production controller
  operations explicitly round at the reviewed binary32 boundaries.
- `reports/native-animation-graph-gpu-v2.json`: 502 checks over 37 authored
  operations using actual external GLB, private models and Vulkan. Up to three
  simultaneous runs, exact Part fields/event order, manual placement before and
  after initialization, material isolation, emitter sampling and actual owner
  release pass. Local position/scale error is zero in this authored case;
  orientations are checked separately. Active/hidden captures differ by 11,477
  pixels. This proves drawing, not original rendering fidelity or FPS.
- `reports/native-animation-rigs-gpu-v1.json`: the existing 65 creature-rig GPU
  checks pass. `reports/native-effect-controller-node-v2.log`: 43 relevant Node
  export/delivery/particle regressions pass.
- `reports/native-controller-effects-local-v3.json`: all 16 dialogue/examine
  and 12 actual server effect checks pass on 127.0.0.1:5121. Healing's original
  `vim_heal01` binary effect occupies the impact slot and uses native runs.
  Its active sample records three native-owned models and one active run
  (including existing background effects). Duration Darkness and instant
  Healing both retire correctly. Renderer errors are empty; the native engine
  log is clean. Effect jobs and particle threads reach zero on shutdown.

Earlier failed reports remain: scheduler v1 created invalid NUL strings and v2
compared decimal-JSON floats before exact-bit input; generic-control v1 used
structural equality in the test's duplicate-controller callback lookup; graph
v1 needed an explicit WeakRef type and v2 exposed strict int/float array lookup
in emitter bindings. That binding bug was corrected in the actual adapter.
Local v1 incorrectly expected retained binary storage on decoded-only Darkness;
v2 inspected Healing's empty ground slot. The final probe finds the actual
impact-slot model and records its active native run state.

## Remaining acceptance

Decoded-only/ASCII resources need an original compilation/storage policy and
multi-run controllers. The installation's `vdr_darkness` lacks retained binary
storage and remains on the diagnosed single-clip fallback. Inherited-animation
scale and motion-run controllers are explicitly unsupported. Animated-vertex
and dangly solvers, light drawing/invalidation, complete depth/blend/rendering
rules, emitter bounds and outer scene/reference event scheduling are incomplete.
Raw nonunit quaternion controller math is tested, but full native scene/skin
presentation for those edge cases is not accepted by this milestone.

Remaining effect programs, controller transforms, view/suppression gates,
dummies, beams/retargeting, projectiles, sound, transition/reconnect races and
the rest of the migration checklist still apply. No Arelith connection was
made. The editor was preserved; these are functional tests, not clean FPS
benchmarks. Complete moving-world sustained >=60 FPS remains unaccepted.
