# Separate native UI preload

User request: provide an explicit **Prebake UI** option separate from world/model
prework. Menus should reuse prepared native artwork across launches, with source
validation for different server/HAK/override/NWSync resources. The separate
option is now implemented: **Main Menu → Options → UI preload → Preload all
menus**. Select installed/downloaded content or Current server. Progress,
results and Cancel UI preload are independent of the Prework model action.
No connection or download is required. An already-running client needs a
restart to expose the new tab.

Preloading is distinct from UI startup admission. The follow-up HUD correction
dispatches its small dependency set first and presents original party/health
and quickbar geometry before all32 rule tables finish. Movement bindings no
longer wait for unrelated spell/feat data. Complex menus/usable shortcuts still
wait for complete rules, with unavailable actions disabled and a short notice.
The profiler now retains individual startup-table timings; the old session log
could not identify its exact slow resource. See the startup receipts and
remaining gaps in [the active UI goal](NATIVE-UI-PARITY-GOAL.md).

## Current implementation (2026-10-28)

`systems/native_ui_preload.gd` mounts a private local catalog through the native
session worker. A worker discovers all GUI documents, referenced/programmatic
GUI models and source states, declared/custom bitmap fonts and the default TTF.
The original scrollbar model is included explicitly. The controller prepares
GUI documents and the default assembled models used by actual layout owners,
then renders unopened artwork with the existing native GUI renderer. It does
not instantiate gameplay menus or send server actions.

Pixels and bounds use the exact finished-icon identity and input validation
already consumed by ordinary menu owners. Worker saves are read back and
validated before success is counted. With Current server selected, already
opened generated poses/regions and replacement layers are captured too, without
changing the live owners. Input/texture changes invalidate the saved result.
Fonts/GUI metadata use the existing decoded-resource cache. Text, current
inventory contents, actor state and unknown future variable-size layouts still
belong to the live menu; preloading cannot freeze those into a screenshot.

The private renderer rotates after16 models, releases each finished texture
after capture and permits at most2 disk-save jobs with a64MiB aggregate image
charge. One waiting packet and the native resource/model caches are additional
memory;64MiB is not a whole-process RSS limit. Cancellation stops new dispatch,
joins active asset/GPU/save work and retains completed files. Source selection
and conflicting preparation/clear operations are locked while UI loading runs.
Model preparation retains its own existing clear/cancel behavior.

The full original-install pass discovers104 GUI documents,1460 model candidates
and9 fonts. It prepares5392 resource/state jobs and saves3819 finished images;
61 non-drawing helpers need no pixel output. A fresh engine reuses all3819
images with zero model renders. The default layout-model request also obtains
a checked persistent hit, so preparation covers more than the visible pixels.
These are functional observations, not a clean FPS or menu-latency benchmark.

Four existing source/reader limitations are reported rather than replaced with
invented resources: `ctl_btn_srv_lan` and `ctl_spellbox_nxt` contain authored
ASCII `sampleperiod 1.#INF` rejected by the current native animation reader;
`fnt_13pp_chat01` lacks its metadata/atlas; `fnt_chatspacer` exceeds the native
font reader's atlas bounds. Four other absent legacy GUI references are
retained in diagnostic metadata. The compatible artwork is still saved and
reused. Complete original UI functionality/parity remains an active goal.

## Verification

- `native-ui-preload-cold-final-v1`: full installed-menu action, progress,
  cancellation, bounded working set, verified saves, exact pixel/bounds
  comparison with unbaked original button states and actual layout-model reuse.
- `native-ui-preload-warm-final-v1`: a separate engine process reuses the full
  saved set without any model rendering.
- `native-ui-preload-dependencies-final-v1`: custom resource discovery, generated
  region capture, isolation of live owners, texture invalidation and mid-bake
  cancellation with drained workers.
- `native-ui-preload-entry-final-v1`: actual protocol-only startup wiring and
  real start/cancel controls, no game-server connection, secondary nonfocused
  window and visible OS mouse.
- Settings, model-prework cold/warm, discovery and ultrawide resize/input
  regression receipts accompany the milestone. Read their scoped acceptance;
  none means the entire UI goal is finished.

## Existing native flow

`native_item_icons.gd` renders original GUI models, states, UVs and replacement
layers in a private graphical SubViewport. `prework_packet()` captures finished
RGBA pixels and original bounds, keyed by exact native inputs. `restore_prework()`
can bypass model preparation/rendering on a later matching request. The asset
service/prework store validates resource inputs and the renderer processor
identity. This is already the right consumer path for persistent prebaked art.

`native_asset_prework.gd` and its remote process separately save processed models and
finished packets from UI that has already been opened. Their separate headless
worker is data-only: it cannot generate new graphical GUI pixels. Fonts,
unopened GUI widgets, all original states and generated frame/scrollbar poses
use the separate graphical UI path above.

Options' original frame still starts lazily through
`native_entry_menu_frame.start()`. Other frame owners also defer some static
model/state work until first use. Once prepared, controls/textures are reused
inside that session, but first opening can still schedule original asset work.
Move static preparation earlier without delaying player/tiles/camera admission
or starting an unbounded competing workload during world streaming.

## Implemented discovery

`systems/native_data/ui_prebake_plan.gd` reads every GUI resource from the active
catalog and recursively collects declared models and font names. It also
includes programmatic original widgets with GUI/panel/control/button/quickbar/
inventory model prefixes. It uses catalog presence rather than installing or
downloading content. Its state planner selects rest and original button states;
size/scrollbar animation controllers are explicitly not treated as correctly
posed static art.

`reports/native-ui-prebake-plan-v1.json` and its debugger receipt pass19 checks
against the original installed catalog:104 GUI documents,1459 available model
candidates,three declared fonts,zero GUI parsing issues and four absent legacy
references retained as metadata. World/creature models are excluded; nested
custom GUI model/font references are covered. The planner does not produce
pixels or a functioning option. Programmatic font names such as
`ttf fnt_default 14` must additionally be included by the consumer inventory.

## Remaining coverage

- Include finished live GUI packets for exact generated poses/replacement layers;
  that capture is implemented for Current server. New unopened variable-size
  frame/scrollbar layouts still require runtime preparation for their exact
  geometry. The standard-state planner alone cannot enumerate every future
  layout or server-defined NUI window.
- Resolve the four source/reader limitations above against original behavior.
- Continue full original menu visual/action parity; prepared art does not enable
  an unimplemented gameplay workflow. No universal menu-speed or full UI claim
  is accepted from this scoped preparation feature.

The [key editor milestone](NATIVE-KEY-SETTINGS.md) is separately built and
locally verified. The [native cursor milestone](NATIVE-MOUSE-CURSORS.md) now
loads original cursor TGAs independently of model-menu preparation and retains
explicit remaining parity gaps. Original table-loader store1402b6446 and
CursorID consumer14086f6a0 identify `cursors.2da` as the physical transition
appearance lookup, not a global cursor filename map. Inventory/store/trade item
wheels still require completion.
