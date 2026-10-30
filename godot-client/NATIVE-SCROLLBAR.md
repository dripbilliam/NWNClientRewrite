# Original scrollbar artwork and fixed GUI animation states

Examine's basic/item windows and the Buy/Sell confirmation now use the active
original `scrollbar_simple`, `pb_scrl_up` and `pb_scrl_down` models. Their
attachment points, size animation, vertex geometry, UV animation, arrows and
thumb caps are retained. A finished screenshot is not stretched to fit.
This is a shared-widget milestone, not full scrollbar or UI parity.

## Original evidence

Read-only original NWN EE executable SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Workspace-level `backups/animations/rea-native-scrollbar-v1.json` records the
original edit attachment, model binding, size and thumb rules, position
rounding and arrow step callbacks. `rea-native-gui-vertex-animation-v1.json`
records the serialized animated-mesh reader, runtime control, ASCII field
parser and original vertex compiler. These are static binary observations;
they are not live original-client screenshot/input oracles.

- `CGuiEditScroll::SetAndAttachScrollBarModel` (`1401eb430`) attaches the model
  at `scrollmin`, stretches toward `scrollmax`, and requests a 20-pixel thumb.
- `CGuiSlider::StretchSizeTo` (`1401e7b00`) samples `size` at
  `(max(3.01, round(distance_pixels)) - 3) / 30`. The original max hook has a
  six-pixel inset. `ResizeThumb` (`1401e7540`) samples `thumbsize` with the same
  conversion. `SetScrollPos` (`1401e7720`) moves the thumb between `min` and
  `max`, subtracting its own length and rounding its displacement to pixels.
- The original rail and thumb center are **animated meshes**, not skinned
  meshes. Earlier research described them incorrectly as skinned. Their node
  feature is `animated-mesh`, flag `a1`; the end caps are ordinary mesh nodes.
- Serialized reader `14007a530` reads the sample period at node `270`, position
  and UV frame counts at `2a0`/`2a4`, and model-section sample offsets at
  `298`/`29c`. Samples are vertex-major. Runtime control `140051e60` interpolates
  positions and UVs and uses one shared sample index: the position clamp can
  affect later UV interpolation, including unusual negative-time or unequal
  stream-length behavior. The native data consumer preserves those rules.
- ASCII `sampleperiod`, `animverts`, and `animtverts` feed the original compiler.
  Native parsing maps their frame-major source vertices and UVs through the
  actual material/face-corner topology into vertex-major streams.

The original scrollbar metadata and payloads are in
`reports/native-scrollbar-resources-v3.json`, `native-scrollbar-deformation-v1.json`
and `native-scrollbar-samples-v1.json`. The original font investigation continues
separately in `rea-native-legacy-font-v1.json`.

## Native implementation

`native_data/animated_mesh.gd` validates bounded finite original sample data
and evaluates it. `actor_model.gd` retains those payloads on physical nodes and
clips, including ASCII topology remapping. The prepared actor decoder advances
to `mdl-actor-packed-v4` and the rig cache to
`actor-rig-emitter-v11-vertex-samples`; old cache entries are not overwritten or
treated as if they contained the new data.

`native_data/gui_pose.gd` composes fixed GUI states. Each state changes only its
present channels: an empty thumb-only rail record cannot erase an earlier
rail-size sample. The original source model and rig remain immutable. The icon
renderer gives the resulting geometry a derived cache identity per pose while
retaining the original source digest. Different sizes cannot alias the same
ResourcePool mesh. Native texture layers separate the rail and movable thumb.

`native_scrollbar.gd` binds those original rasters and arrow states to the
actual Godot content range. Arrows, rail paging, thumb dragging and mouse wheel
change the displayed text; they send no gameplay request. Scrolling moves a
cached thumb and does not prepare or render another model. Hidden windows
retire thumb drags, and close disconnects listeners. Resource failure leaves
the generic scrollbar fallback and records an explicit diagnostic.

Examine reads the original edit hooks. The merchant confirmation wraps its
existing localized prompt in a native scroll container; its action and
authoritative transaction path remain unchanged. Ordinary GUI model requests
retain their prior cache keys and renderer behavior when no fixed pose is
requested. The existing JS protocol service is unchanged; no JS renderer or
browser font/image preparation is introduced.

## Verification and limits

Source-pinned final receipts:

| Receipt prefix `native-scrollbar-` | Checks | Scope |
| --- | ---: | --- |
| `pose-checkpoint-v1` | 69 | Original binary payloads, multiple rail/thumb sizes, channel composition, immutable data, malformed bounds/counts, cache separation, ASCII interpolation and native shared-index edges |
| `examine-checkpoint-v1` | 43 | Actual injected input, original art and portrait, long text, arrows, paging, drag, wheel, 125% scale, no per-scroll model rendering, Identify lifecycle |
| `store-checkpoint-v1` | 30 | Original merchant/confirmation controls, native scrollbar activation, localized prices, original model proportions |
| `inventory-checkpoint-v1` | 157 | Inventory frame, equipment, grid and native input regressions |
| `barter-checkpoint-v1` | 28 | Native barter window/control regressions |
| `retirement-checkpoint-v1` | 13 | Real GUI models closed during pending GPU readback, later rendered frames and worker retirement |
| `text-checkpoint-v1` | 1025 | Native text/token regressions |
| `playability-checkpoint-v1` | 1314 | Native gameplay/streaming/rule regressions |
| `art-binding-checkpoint-v1` | 8 | Stale native artwork delivery guards |
| `actions-checkpoint-v1` | 99 | Original owned loopback server transactions, free Lore and paid Identify with exact fees, and existing gameplay regression |

All final native receipts have debugger armed, exit 0, unchanged source and no
native exception or script/lifetime error. The local run retired with zero
workers. No public server connections. Item, creature, long-scroll, scaled and
merchant confirmation captures were visually reviewed. The native 20-pixel
thumb has seven occupied interior rib rows under the chosen pixel threshold;
the original 312-pixel rail is 12×312, not an empty 3-pixel rest mesh.

Failed experiments remain retained. Early tests did not assert native art was
active; later checks caught that missing-animation fallback, a missing wheel
release in the synthetic input test, erased rail channels, and an incorrect
assumption about original cap overlap. A merchant test also waited for its
panel before creating the test world; its isolated process was terminated and
the test ordering corrected. None of these receipts counts as acceptance.

The broad local action runs `actions-final-v1` and `actions-checkpoint-v1`
passed all99 checks. `actions-accepted-v1` passed the UI/Identify checks but
failed the pre-existing transient blood-particle screenshot assertion. That
intermittent visual-test failure remains open; a green repeat does not prove
it resolved. No particle/combat behavior was changed in this UI work.

Full parity remains unproven: original held-arrow/held-rail repeat timing,
precise line/wheel step behavior, edge/disabled states, arbitrary active-server
variants, all UI scales and live original-client comparison still need audit.
The shared control currently uses a 14-pixel line step and three-line wheel
step. General animated-mesh gameplay playback is not implemented by this fixed
GUI-state consumer and is not claimed here. Fonts and Examine body formatting
are next. Keep `full_scrollbar_parity` and the full UI goal incomplete.

Rollback: `backups/native-scrollbar-v1.zip`; audit:
`node godot-client/tools/audit-native-scrollbar.mjs`. The preceding verified
checkpoint is `native-examine-identify-v1.zip`.
