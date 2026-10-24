# Animated character density and skin mesh updates

2026-10-20. No live input/reconnect/server change this turn. The owned local
replacement remains open on its earlier build. Tests use installed assets
through a local bridge; no server connection/download or proprietary asset
payload is written to this workspace.

Earlier density tests primarily exercised static placements. The new fixture
assembles separate production NetworkScene character instances and animators
from the recorded Prelude wizard. One scenario retains the recorded multipart
body, another selects robe3 through the normal body-part/armor data. Exploratory
scaling runs cover1/8/24/48 characters. Native body/robe playback, vertex skinning,
materials, renderer light admission and shadows use production callbacks.
Placements, camera and synchronized in-place run poses are synthetic; no new
server-owned movement is manufactured in the actual client.

At48 characters there are99 animators (including three area animators) and48
independently owned skinned meshes. Position-buffer versions/values and model
pose fingerprints change over time. Canonical fixture actors remain unchanged.
Initial phase profiling located more time in mesh update than bone deformation:
the first48-robe measurement had roughly3.1ms mesh work of5.0ms skin work.

`buildMesh` expands faces by material into non-indexed Float32 triangles. Three's
generic `computeVertexNormals` clears all existing normals, writes each triangle
cross product three times, then normalizes all three identical stored normals.
The new skin adapter skips the clear and normalizes once per triangle. It retains
the intermediate Float32 rounding of the cross product before normalization;
normalizing the original double cross product directly would change the result.
Indexed, interleaved, normalized and differently encoded attributes keep the
generic Three path. Position writes avoid per-vertex callback/spread work.
Bounding sphere computation and lazy bounding-box invalidation are unchanged.

32 focused checks pass. New property-style comparisons use the independent
Three implementation across repeated source indices, varied scales, degenerate
and signed-zero triangles, empty meshes, indexed/normalized/interleaved data;
position/normal bytes, versions, sphere and rebuilt box agree. Existing skin-bone
native observations, animation/pose, network model and preparation checks pass.
This preserves the renderer's existing normal policy; it does not claim new
native GPU skin/normal or pixel equivalence.

The final paired fixture loads either the saved previous adapter through a
QA-only Vite load hook or the current adapter. It records the actual executed
implementation in the renderer and confirms the reference hook ran. Both use
production tile shadow configuration and identical48-character/300-frame cases,
fixed1/60 animation delta, nine shadow maps and actual3100x1121 framebuffers.
The first30 frames are excluded from settled statistics. Timings split animation,
deformation, mesh update, matrices, lighting and render submission plus gl.finish.
The local client/background load and driver caches remain uncontrolled.

Final current v10 precedes reference v11, reversing the earlier v8-reference /
v9-current order. Sampled position and normal byte hashes, pose fingerprints,
all per-frame main draw/triangle counts, memory counts, programs and final shadow
workload agree. Results are in `creation-performance-animated-crowd-proof-v1.json`;
the verifier reports both median and p95 without deriving live FPS from them.
The earlier matched v8/v9 pair measured48-robe mesh median3.1ms ->1.1ms and
completed work19.8ms ->17.7ms. Exploratory v1-v7 lacked one or more later runtime
variant, shadow-accounting or actual-framebuffer checks and are retained as such.

Geometry/texture/program counts stay stable throughout each measured case.
The known tile-flame attachment and slow-resource diagnostics remain recorded;
there are no renderer errors or GL errors. The current production build also
passes packaged startup/resource IPC with no join/fetch. It is ready for the
next reload and has not replaced the open local client this turn.

This is a measured CPU skin-work reduction. It does not establish the full cause
of the reported10FPS or minute-long dense-server load. The fixture has nine active
point lights with16 point shader slots, unlike the user's earlier42/128-light,
15-shadow report. A useful next pressure check should model that light/capacity
history together with animated characters before attributing remaining work to
geometry alone. Varied live replicated populations, transitions, fullscreen,
physical feedback and the existing resource gaps remain separate goal work.
