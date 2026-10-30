# Direct-native server effects and original WAV playback — partial migration

The current `join-native.ps1` entry now consumes looping A/D records and ordinary
targeted instant visual packets without JS resource or scene preparation. Godot
reads the admitted session's `visualeffects`, `progfx` and `appearance` tables,
loads original models/textures on native asset workers, and owns private model
instances, original controller runs, attachment, phase timing and removal.
Canonical gameplay state and outcomes remain exclusively server-owned.

This is a scoped integration milestone. **Full binary parity and play alongside
original-client users remain the top acceptance requirement.** It is not full
effects, audio, projectile, multiplayer or migration acceptance.

## Current owners

| Concern | Native owner / boundary |
| --- | --- |
| Decoded records | `tools/raw-visual-events.cjs`: clone raw input and shared source identities; no tables/models/presentation |
| Active-table selection | `native_data/visual_definition.gd`: original loader geometry/program/size/quality/default decisions |
| Resource IO and preparation | `native_data/asset_service.gd`: bounded worker jobs; native catalog/cache/resource precedence |
| Binary run/controller storage | `native_data/actor_model.gd`: physical IDs/order, raw controller/value pools and clip trees; rig cache version bumped |
| Private models and attachment | `native_render/effect_model.gd`: original model rig/skin owner and retained native named-run/controller playback |
| Effect list and phases | `native_render/effect_world.gd` reuses `visual_world.gd`, `visual_runtime.gd`, native phase/clock/selection owners |
| Original WAV decoding | `native_data/wave_data.gd`: validated RIFF and IMA blocks on workers, including stereo channel groups, predictors and fact limits |
| Playback | `native_render/effect_audio.gd` feeds decoded data directly to `world_audio.gd`; existing listener, positional gain, loop and source lifetime owners remain native |

The protocol runtime remains transitional JS for authentication, downloads,
packet codecs and raw state. Offline JS tools are reference oracles only. No
GLB, exported effect definition, staged particle metadata or audio byte transfer
is consumed by this native rendering path.

Each world owns the effect tables, raw queue, private models and sound sources.
Connection/generation/area checks precede delivery; canonical source lifetimes
reject reused IDs. Temporary model replacement preserves the logical effect and
rebinds to the replacement's original parts. Newly prepared definitions wait for
the current appearance. Removal also clears reservations which never obtained
a model. Assets participate in world retirement, cancellation and worker joining.

The frame owner visits only actors referenced by pending/active effects. It does
not scan static scenery or every creature each frame. Detailed profiling includes
separate `callback_effects` and `callback_audio` spans. Particles remain **off by
default**; the explicit visual test enables them in memory and restores the
previous setting without changing user preferences.

## Verified evidence

- `reports/native-effects-direct-live-v6.json`: **11 checks pass** on the unchanged
  owned original server, isolated port **5125**, authored `GodotSounds2` module.
  Actual `-native-vfx` produces duration Darkness; `-native-vfxi` produces instant
  Healing. Native original models start, attach, draw and retire. Hiding only the
  tested model with simulation frozen changes 7,003 sampled viewport pixels in
  the earlier accepted v4 capture; final v6 records its own pixel result.
  Original `sdr_darkness` and `sim_heal01` WAV resources decode and play through
  actual native positional sources. Test model owners retire while unrelated
  existing buffs remain. The unobscured effect capture was inspected.
- `reports/native-visual-definition-final-v1.json`: **723 checks** across 120
  authored original-derived loader cases, plus serialized identity/controller
  boundaries. Physical table rows, geometry/program selection, defaults, size,
  quality, instant/duration and creature/placeable/door anchors match the retained
  reviewed loader. This is not a fresh binary observation or every server table.
- `reports/native-effect-data-final-v1.json`: **66 checks**. Two installed effect
  models' physical IDs, types, controller/value hashes and complete clip trees
  match the independent retained reader/exporter. Twenty-four authored mono/stereo
  IMA files decode to exactly the reference PCM samples and format. Original asset
  payloads remain outside the authored workspace.
- `reports/native-visual-lifetime-final-v1.json`: **8 checks**, including model
  replacement, temporary render absence, reused IDs, removal and deferred cleanup.
- `reports/native-effects-actions-regression-v1.json`: the existing **62** real
  inventory/equipment/spellbook/quickbar/party/store/advancement/combat checks pass
  with the new effect implementation present.
- `reports/native-effects-node-v1.log`: **24** raw transport, cancellation,
  private-login and retained visual-definition regression tests pass.
- `reports/native-effects-lifecycle-final-v1.json`: cancellation, disconnect with
  streaming work pending, two original Prelude reconnect cycles and stale-message
  isolation. Normal-heap native exception capture and final worker cleanup remain
  required for the result to pass.

The accepted runs pin source hashes and make **zero public server connections**.
Functional timing captures are not clean FPS benchmarks; another user game may
be active. The final v6 timing window measures about 0.208 ms mean for the effect
owner and 0.042 ms for audio in this small local scene. This does not establish
large-room performance or native-binary rendering parity.

Reproduce locally:

```powershell
./godot-client/tools/test-native-actions.ps1 -Effects -Profile -Run unique-effects-run
./godot-client/join-native.ps1 -LocalCheck -LocalCycles 2 -LocalStreamAbort -LocalCancelCheck -Debugger -Run unique-lifecycle-run
```

The helper stops only its own verified isolated server. The ordinary Prelude
server and unrelated games/editors are preserved. Original scripts/resources are
referenced, with no custom authoritative outcomes in the client.

## Limits and next work

Follow-up: original P/B routing, private point/source/target hosts, type-11 area
visuals and real lightning beam delivery now have scoped direct-native evidence;
see [point/area/beam delivery](NATIVE-POINT-AREA-BEAM.md). A later
[projectile milestone](NATIVE-PROJECTILES.md) adds native common-path ownership
and real server-timed homing spell flight; full ranged/specialized paths remain
incomplete. Nonidentity effect controller maps and
nondefault looping body-part delivery are explicit diagnostics. Several program
types, animated lights, shake, selected-view context and specialized finalization
remain incomplete. ASCII/inherited native-run controller reconstruction remains
unavailable rather than fabricated. Particle wind/collision and other previously
documented particle limits remain visible in diagnostics.

Original effect WAV PCM/IMA playback is locally verified. BMU/other compressed
formats, ambient/music/scripted sound integration, full mixer/voice priority,
and exact original playback scheduling across all formats remain open. Capturing
decoded sample identity does not prove acoustic or timing parity by itself.

Failed runs remain retained: initial JSON numeric-key identity rejection;
unconnected raw named-controller playback; unsupported direct compressed-WAV
loading; missing loop-frame metadata; and an assertion which incorrectly counted
unrelated preexisting buff models as leaked test models. A diagnostic oracle run
also failed to generate its input because a URL path was not decoded; only that
owned stalled test process was stopped, then the input path and missing-input
guard were corrected. Passing runs resolve those specific causes, not every
documented fidelity or compatibility limitation.

The controller/run owners reuse the read-only findings and original target hash
recorded in [NATIVE-EFFECT-ANIMATION.md](NATIVE-EFFECT-ANIMATION.md). Reviewed loader
entry: `LoadVisualEffect14096cf10..14096ed64`; receiver routing reference:
`1407857f0..14078644b`. No original process was patched or modified. Original
paired-client acceptance remains required by [the active goal](BASE-GAMEPLAY-GOAL.md).

Verified checkpoints: `backups/native-effects-direct-before-v1.zip` and
`backups/native-effects-direct-after-v1.zip`. Final evidence index:
`reports/native-effects-direct-final-audit-v1.json`.
