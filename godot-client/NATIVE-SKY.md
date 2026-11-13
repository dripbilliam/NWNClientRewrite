# Original-model sky — partial rendering milestone

The current all-native live-world follow-up is documented in
[NATIVE-LIGHTING-CORRECTION.md](NATIVE-LIGHTING-CORRECTION.md). It reads original
sky table/model/bitmap resources through native workers and preserves their
original RGBA vertex bytes. The GLB/reference-delivery work below is historical;
it is not the native live renderer's sky loading path.

Ordinary native sessions now resolve the received area's SkyBox byte through
the active session's `skyboxes.2da`, export its original dawn/day/dusk/night
models and install them in a camera-centered Godot sky owner. Model geometry,
textures, UVs and resource precedence use the existing installed/module/HAK/
NWSync/Workshop resolver. Game art stays in external runtime bundles. There is
no invented gradient or replacement sky texture.

The sky draws unlit, without world fog, shadows or depth writes, at Godot's far
depth. World geometry still occludes it. This approximates the native separate
sky pass using Godot's reversed-depth projection rather than the original
temporary 1000-unit projection and render-state calls. Camera translation and
world clipping do not move or remove the backdrop. Only the two active phase
models are visible; unchanged weights do not repeat surface/uniform updates.

## Original observations

Read-only original target: `../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`,
SHA256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

- Area sky loader `1407e1930` reads the physical SkyBoxes row and four columns
  beginning at DAWN, loads original model resources and installs the scene set.
- `Scene::SetSkyBox1400d3d70` installs those four resources.
- Area phase `1407e90b0` selects dawn/day/dusk/night using the .4/.6 transition
  boundaries; `1407e9cb0` applies clamping and .99 completion, then calls
  `Scene::SetSkyAlpha1400d3d40` to track current/target/alpha.
- `Scene::RenderSkyBoxes1400d28f0` uses a separate camera-centered sky pass with
  fog/lighting/depth-write state changed temporarily and a 1000-unit far clip.
- `reports/native-sky-{load,phase,select,set}-v1.json` preserve the relevant REA
  dossiers. These are decompiler observations, with their recorded limitations.

`tools/native-sky-state-oracle.py` executes the original phase/update/scene-alpha
instructions in isolated Unicorn. Module/settings/color/tile/weather/render
boundaries are explicitly stubbed; there is no original process mutation.
`tests/fixtures/native-sky-state-v1.json` holds 114 sequential cases, including
boundary values, late phase entry and different module durations.
`reports/sky-state-v1.json` confirms **570 exact numeric/state comparisons**.
This establishes the bounded state behavior, not complete native GPU parity.

## Native and local evidence

- `reports/sky-portals-local-v1.json`: real owned-local A→B→A, three animated
  admissions and 14 native portal checks. All three area sky messages apply,
  selecting original day/night/day models. Each area owns and imports its four
  resources, with distinct generation/ticket scope. Retired native owners free.
- `reports/sky-render-v5.json`: **27 offline Vulkan checks** using the actual
  exported original assets from that local session. Checks include geometry
  counts (two meshes/160 triangles per phase), imported-material UV/color pixel
  comparison, camera translation, world fog/short-clip isolation, day/night and
  dawn images, foreground occlusion, no repeated fixed-phase uploads, corrupt
  hashes/missing phases, no-sky replacement and old model/rig owner retirement.
  The two asset-rejection warnings in its log are deliberate negative tests.
- `reports/sky-atmosphere-state-v1.json`: all **6,468** existing original
  fog/color/phase/shadow comparisons still pass.
- `reports/sky-atmosphere-native-v1.json`: all **23** existing native atmosphere
  integration checks pass.
- `reports/native-sky-backend-v1.log`: **44** focused scope, sky delivery,
  external-bundle, ownership, handoff/recovery and endpoint cases pass.
- `reports/sky-normal-local-v1.json`: ordinary local gameplay/dialogue/examine
  regression, with no sky configured in that module.

Tests used only owned localhost servers or offline assets. The ordinary
GodotFeedback1 server was restored, and the existing editor was preserved.
The displayed FPS values are not performance acceptance or clean benchmarks.

## Remaining work

The original `skyfade1` horizon overlay and corrected native material behavior
are implemented in a follow-up. The subsequent explicit native retirement path
passes repeated owned-local and NUI/NWSync recovery checks. See
[NATIVE-HORIZON.md](NATIVE-HORIZON.md) and [NATIVE-SHUTDOWN.md](NATIVE-SHUTDOWN.md).
This earlier sky checkpoint is retained as a rollback point.

Precipitation, lightning, weather sound/transition ownership, scripted dynamic
sky changes, sky/resource failure retry UI, full graphics settings and broader
custom sky catalogs remain incomplete. Existing JS weather explicitly reported
itself unconnected; installed `weathertypes.2da` points to original `fx_rain` and
`fx_snow` resources for subsequent work. Fog still uses the previously documented
Godot depth-fog approximation. Public-server rendering and complete moving-scene
performance have not been accepted. The full migration goal remains active.
