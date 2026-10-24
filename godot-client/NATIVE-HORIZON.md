# Native sky material and horizon follow-up — work in progress

The native sky owner now includes the original `skyfade1` model and its
`skyblurpoly` bitmap through the active resource resolver. Its 112 triangles,
original UVs and bitmap alpha remain intact. It follows the camera, draws after
both sky phases at far depth, receives the current native fog color and leaves
foreground world geometry in front. No game art is copied into the workspace.

This follow-up also corrects the previous sky shader's additive transition and
mesh diffuse tint. The original material path uses normal alpha blending and
white color modulation for sky phases. The horizon uses fog RGB/alpha1 instead
of the mesh's diffuse tint and part alpha. All 18 phase/horizon material
instances now share one shader resource per admitted area; unchanged weights
and fog color still avoid repeated surface/uniform updates.

## Original evidence

Read-only `nwmain.exe` SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

- Area loader1407e1930 loads `skyfade1` after the four SkyBoxes models.
- `Scene::SetSkyFade1400d3dc0` installs it and sets object flag+19.
- `Scene::RenderSkyBoxes1400d28f0` draws it after both active phases.
- `PartTriMesh::Mat1400a2f50` is decisive: flag+18 multiplies part alpha by
  object alpha, sets normal blending and white RGBA; flag+19 sets the scene fog
  RGB and alpha1 instead. The latter ignores mesh diffuse tint and part alpha.
- `GLRender::SetBlendFunc1400b6910` indexes the table at140d8aca0. Entries0/1
  are GL_SRC_ALPHA770 and GL_ONE_MINUS_SRC_ALPHA771. The scene's outer blend
  selection alone was insufficient evidence because PartTriMesh::Mat changes
  it before drawing each phase.
- REA dossiers: `reports/native-horizon-{set,material,gl-blend}-v1.json`.
  Decompiler output and unknown shader/driver boundaries remain explicit.

`tools/native-sky-material-oracle.py` executes the actual original material
instructions with synthetic mesh/scene owners and stubbed texture, custom
shader and driver operations. `tests/fixtures/native-sky-material-v1.json`
contains32 cases and the original GL blend table. No live original process is
modified. `reports/horizon-material-oracle-v2.json` compares the actual
production Godot sky shader against independent standard materials using the
original instruction RGBA outputs:24 sky/horizon cases, zero pixel difference.
The ordinary world-mesh0/0 flag path is outside this sky shader's scope.

## Current functional checks

- `horizon-render-v7.json`:35 offline Vulkan checks with actual exported
  original sky/horizon assets. Includes the independent native-color/alpha
  material path, phase blending, fog tint pixels, ignoring horizon mesh tint/
  part alpha, one shared program, geometry/UVs, camera following, world fog and
  clip isolation, foreground occlusion, bad assets and actual node retirement.
  Asset rejection warnings in its log are intentional negative cases.
- `horizon-portals-local-v4.json` and `horizon-portals-local-v5.json`: normal
  local day/night/day A-B-A checks after shader sharing, three animated
  admissions and14 portal checks per run. All areas receive five original
  resources and the correct horizon fog RGB. The latter records whether the
  host had to force termination.
- `horizon-lifecycle-v1.json`:24 offline replacement/render cycles,120 original
  model imports,144 retired sky/model references, zero survivors and exit0.
  Resource/texture observations are recorded; this is not whole-world FPS or
  complete stability acceptance.
- `horizon-normal-local-v1.json`:16 ordinary local dialogue/examine checks,
  graceful exit0 and no-sky behavior.
- `horizon-sky-state-v1.json`:570 original sky-state comparisons pass.
  `horizon-atmosphere-state-v1.json`:6468 original atmosphere comparisons pass.
  `horizon-atmosphere-native-v1.json`:23 existing Vulkan atmosphere checks pass.
- `native-horizon-backend-v1.log`:44 focused backend/ownership/policy cases pass.

All tests are owned localhost or offline. The editor is preserved. These
checks do not accept the sustained moving-scene60 FPS objective.

## Shutdown investigation and acceptance boundary

The shutdown investigation was continued with repeated reproduction and an
explicit retirement lifecycle. See [NATIVE-SHUTDOWN.md](NATIVE-SHUTDOWN.md).
The history below describes this work-in-progress checkpoint; it is retained
as evidence and does not override the newer measured shutdown results.

`horizon-portals-local-v2.json` must remain a failed run: its gameplay checks
completed and old world references were released, but Godot exited with
0xc0000005 during shutdown. No useful Windows fault event or dump was observed.
The cause is unproven. The debugger rerun `horizon-portals-local-v3.json` exited0;
`horizon-shutdown-cdb-v1.log` contains no unhandled AV. Later non-debugger and
replacement-stress checks pass, but neither shader sharing nor altered timing
proves the original failure is fixed. Do not describe it as a diagnosed or
resolved engine/driver issue. The host now records graceful-vs-forced shutdown.

Save this work as `backups/native-horizon-wip-v1.zip`; retain the558-file
`backups/native-sky-tested-v1.zip` as the last accepted rollback. Functional
horizon/material evidence is recorded, while shutdown stability remains an
open investigation. The full migration goal stays active and incomplete.

Precipitation/lightning, weather audio/transitions, dynamic sky commands,
broader graphics preferences and custom sky catalogs remain to be migrated.
Weather investigation found native major4/minor4 sends a weather byte and bool,
and installed WeatherTypes references original rain/snow model resources; their
presentation is not yet wired. No Arelith/public server connection occurred.
