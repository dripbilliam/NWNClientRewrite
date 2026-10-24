# Native terrain experiments

`./godot-client/native-area.ps1` starts a native-only terrain review with FPS and
camera controls. It reads the owned `GodotFeedback1.mod` and installed originals
directly, without JS/Electron or any server connection. Multiplayer is unchanged.

ARE/SET parsing and original asset preparation use native workers. Unique models
prepare once per area, GPU publication has a frame budget, old generations cannot
publish, and close drains worker tasks. A-B-A reuses immutable GPU resources.

Experimental terrain instancing uses original opaque/alpha-tested geometry in
4x4-tile MultiMesh cull groups. Blended surfaces retain individual depth sorting.
Original meshes, textures, transforms and shadow flags remain intact. Dynamic
behavior requiring another owner fails explicitly. Actors, effects, animations,
lighting, collision, UI and complete multiplayer rendering remain incomplete.

## Evidence

- `native-area-data-v1.json`: 442 native ARE/SET checks, actual local areas,
  authored rotations/heights, original byte hashes and invalid inputs.
- `native-area-render-v4.json` / `.debugger.json`: 612 native Vulkan checks for
  100-tile A-B-A, camera orbit, resource reuse, cull granularity, cancellation,
  missing-area failure and cleanup. No trapped exception or engine/lifetime error.
- `native-area-entry-v1.json` / `.verification.json`: actual native launcher,
  worker catalog indexing, camera/FPS entry, 120 frames and debugger/source/exit checks.
- `native-area-batch-image-v2.json`: output is byte-identical to prior native
  per-tile rendering over all 691,200 fixed-camera pixels. Terrain-only acceptance.
- `native-area-unbatched-v1.json`: same current test with per-tile nodes.

Reports are under `reports/`. Warm terrain builds measured 5.36/4.46 seconds with
per-tile nodes and 0.73/0.38 seconds with spatial batching. Cold builds were
0.92 versus 1.48 seconds. Catalog indexing is separate. Editor preserved: these
are functional observations, not clean benchmarks or production acceptance.

**No steady-rendering win is demonstrated.** Both small-scene paths had roughly
1.2–1.5 ms median orbit-frame observations; batching increased submitted draws
from 381 to 505. Coarse culling and Godot's own instancing matter. Initial batch
preparation also causes a large main-thread hitch. Do not promote this experiment
on warm loading results or treat this small static scene as playable-world proof.

Next priority is the complete captured laggy room, comparable lighting/camera/
resolution, moving creatures/effects and responsive input. Measure main/render/
GPU work and p95 frame pacing. The >=60 FPS goal and historical native shutdown
AV remain unresolved. No public server was contacted.
