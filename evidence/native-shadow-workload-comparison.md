# Original NWN shadow policy versus replacement workload

Read-only investigation, 2026-10-21. No game inputs, connections, original
binary changes, or renderer changes were made. The performance goal remains
paused. This is a static implementation comparison plus observed settings and
replacement counters, not a measured native GPU capture of the current room.

## Target and native evidence

Original NWN:EE 89.8193.37-17, x86-64 `nwmain.exe`, at
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The REA `open_binary` identity was checked again for this investigation. Saved
Ghidra dossiers below identify the same binary digest.
The fresh `Scene::RenderShadows` analysis request did not return during this
check and was cancelled; no new dispatcher dossier or live GPU count was
obtained. The native function findings below come from the complete retained
analysis for the verified identical binary, not from that cancelled request.

* `Scene::RenderDynamicShadows`, `0x1400ce3a0`, requests
  `vs_shadowvol` / `fs_shadowvol` at call `0x1400ce4a6`. It configures separate
  front/back stencil operations at `0x1400ce5e5`, `0x1400ce5f8`, `0x1400ce69a`
  and `0x1400ce6ab`, then submits shadow-volume vertex data at
  `0x1400ce7aa`. The inspected function uses shadow draw buckets and the
  selected light; it does not implement six cube-face depth-map rendering.
  Dispatcher calls from `Scene::RenderShadows` occur at `0x1400d0c6f` and
  `0x1400d0e1f`. Validation: complete retained pseudocode, assembly and call
  references in `backups/animations/rea-performance-shadow-render-current.json`.
* `LightManager::GetShadowLights`, `0x14007f840`, filters its normal selection
  by shadow radius (falling back to light radius), uses
  `m_nMaxShadowLights`, and retains fading previous selections. Mode 1 requires
  the dynamic flag and breaks after the first eligible addition. Mode 2 has a
  separate selection path. Thus the configured limit is not a proof that every
  native shadow category combined totals three lights.
  `Scene::RenderSinglePass` calls modes 1 and 0 at `0x1400d111b` and
  `0x1400d1135`, storing separate lists at scene offsets `0x60` and `0x70`.
  Validation: `rea-performance-shadow-lights-current.json` and the full saved
  `rea-light-selection-scene-single-pass-full.json` analysis view.
* The `numbershadowlights` console setter, `0x1400812f0`, writes the configured
  value to `m_nMaxShadowLights` at `0x14128e58c` (write instruction
  `0x14008131a`). Validation: `rea-performance-shadow-config-current.json`.

Both observed original profile files,
`Documents/Neverwinter Nights.0/settings.tml` and
`Documents/Neverwinter Nights/settings.tml`, contain this effective settings
block (outside the write-only schema):

```toml
[graphics.shadows]
all-types-can-cast-dynamic = true
max-casting-lights = 3
[graphics.shadows.creatures]
mode = 2
[graphics.shadows.environment]
enabled = true
```

The settings schema also declares a default of 3 and normal constrained range
1 through 3. These are file observations, not a read of a running native
process's actual setting or proof against a console override.

## Replacement implementation and observed cost

At the start of this investigation, `src/renderer_shadow_budget.js` admitted nearest shadow-requesting
lights up to the GPU sampler allowance after material reservations. It does
not apply the native configured shadow-light count, separate native lists,
shadow-radius selection or fade history. In this room it admits 15 shadow
lights from 30 active lights. This hardware safety guard is not native policy.

Three's `PointLightShadow` declares six viewports. `WebGLShadowMap` renders
the shadow scene for each viewport. `RendererShadowTraversal` records actual
renderer call/triangle increments across the complete shadow operation,
including every light and face. Five reused maps skip drawing; ten updated
point maps still schedule sixty face passes, each with its own caster/frustum
tests. The main pass uses one camera view and has different visible membership.

User-provided current sample: 453 main / 2,697 shadow draw calls, and 20,870
main / 199,085 shadow triangles. This is about 5.95 times the main draw count
and 9.54 times the main triangle count, not thousands of shadow lights or
independent complete copies of the main view. Shadow casters outside the main
view can contribute. The counter is consistent with the implemented multi-face
path; this does not establish that the workload is necessary for NWN parity.

## Conclusion and limits

There is an established algorithm and selection-policy mismatch. The original
dynamic path uses stencil volumes with selected light lists and a configured
limit of three in both observed profiles. The replacement uses up to fifteen
sampler-limited shadow lights and six-face point maps. More workers or only
main-pass batching will not remove that redundant shadow submission structure.

The next implementation work should reproduce native light selection/settings
and caster eligibility before treating fifteen full point-shadow maps as the
required visual workload. A simple three-map clamp alone would not reproduce
the separate lists, fades, static/dynamic shadow paths or native appearance.
Native GPU call counts for this exact room remain unmeasured; no numerical
native-versus-replacement shadow draw ratio or guaranteed FPS gain is claimed.

## Implemented selection adapter and local validation

The replacement now enables `RendererNativeShadows` before the sampler hardware
guard. It applies the native positive RGB >0.1 / ambient-only eligibility,
existing verified native light-priority score, shadow-radius fallback, and
normal/dynamic selections. Mode 1 runs before mode 0 and both share the same
float32 fade values, following the original call order. Removed lights and
retired areas release the previous lists, fade records and budget owners;
reset restores authored shadow requests and opacity. Light color and intensity
remain active for every light, including those not selected for shadows.

Options now has a persistent **Shadow-casting lights** control, range 1–3 and
default 3, matching the observed original profile default. It is the
replacement's own preference, not automatic synchronization of the original
profile files. Each native list is bounded by this value; the union can exceed
three during dynamic selection/fading. Point-shadow shader reservation is
bounded by twice the chosen value (six by default), plus foreign point lights,
and still respects hardware limits. Non-model lights retain the existing path.

`scripts/inspect-native-shadow-selection.py` executes the original
`GetShadowLights` machine code in an isolated emulator. All **500 synthetic
cases** match the replacement's selected lists and shared float32 fade values.
List storage/allocation, copies and frees are explicit helper boundaries;
candidate construction, sorting and rendering are not executed by that oracle.
The 34 focused light/shadow checks and 29 related model/preparation/retirement
checks passed.

The authored offline GPU fixture passes 12 frames, including a moving caster
and changing selection focus. Native-policy pixels and shadow counts match
direct rendering with the same selected lights/fades. The initial frame drops
from **2,374 shadow draws / 15 lights** to **570 draws / 3 lights**. This is a
76% submission reduction in that fixture, not an FPS promise or proof of
original stencil-volume pixels. Earlier rejected fixture attempts lacked an
import map (v1) and reused a lost WebGL context (v2); v3 uses fresh contexts and
passes without renderer errors. Those failures were in the harness.

The separate local native-server check completes dense_a → dense_b → dense_a,
with 48 moving actors per visit, zero renderer/model failures and successful
worker, geometry, preparation, shadow-proxy and program-lease retirement. It
uses a transient browser partition and a fixed loopback endpoint; it neither
changes nor reconnects the user's current client. An initial attempt with a
different user-data directory could not decrypt the profile-bound saved key;
the passing run reads the existing protected store in the main process and
isolates browser storage with the transient partition instead.

That background run had sparse shadow lights and concurrent user-client load:
load readiness was 33.36/29.39/21.22 seconds and reported FPS-window means were
12.8/13.7/14.9. It is a lifecycle check, not a comparable speed benchmark or
evidence that the 60 FPS goal is met. No Arelith connection was made by tests.
The owned local server is stopped after the check; the user session is intact.

The production build `index-e9m730-x.js` is enabled by default for this selection
adapter, with experimental main batching still off. It matches the tested
bundle SHA256. Artifacts: `native-shadow-selection-observations-v1.json`,
`native-shadow-policy-v3.json/.png`, `dense-local-native-shadows-v2.json`, and
`native-shadow-policy-proof-v1.json` in `backups/animations`. Reproduce the
source/bundle/artifact checks with `node scripts/verify-native-shadow-policy.mjs`.

Remaining limits: the renderer still uses Three's six-face point shadow maps.
Native stencil volumes, special owner overrides, mode-2 static projections,
static/dynamic caster buckets, per-object selection and exact std::sort ties
remain unfinished. This change preserves existing authored mesh shadow flags;
it does not establish full native caster or pixel parity. The broader
performance goal remains paused and incomplete.
