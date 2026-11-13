# Compiled particle arithmetic

`particle_kernel.cpp` uses the engine's C GDExtension ABI directly; no godot-cpp,
JavaScript, scene export, external rendering service or runtime compiler is
required. The ABI header and JSON are dumped locally from our pinned single-
precision Godot 4.7.2 console executable. This follows the official
[C extension example](https://docs.godotengine.org/en/4.4/tutorials/scripting/gdextension/gdextension_c_example.html)
and [GDExtension system documentation](https://docs.godotengine.org/en/4.7/engine_details/engine_api/gdextension/index.html).
The build checks executable hash, API version/precision and relevant ABI sizes;
it compiles with MSVC `/O2 /fp:strict`, without fast math/FMA reassociation.

From the workspace, run `./godot-client/tools/build-particle-kernel.ps1`.
MSVC x64 and the Windows SDK are prerequisites. Generated API/build files and
DLL stay in ignored `.tools`/`.cache` directories. The build manifest records
source, header, API, compiler, engine and DLL hashes. Checkpoints include authored
C++/GDExtension/build sources, not proprietary game content or generated binaries.

The [compiled simulation follow-up](../../docs/rendering.md) makes this
the Windows default after original-output, moving-emitter, GPU and local checks.
Normal and captured launchers validate/reuse the build before opening Godot.
`-GdParticles` selects the previous GD path. Explicit native arguments also allow
`--particle-kernel=compiled`/`--particle-kernel=gd`. Failure is diagnosed without
silently switching arithmetic implementations. Full visuals/performance remain
incomplete; vertex-only opt-in evidence below is historical after this increment.

`NwnParticleKernel` is an abstract RefCounted class exposing a static vertex
method. Arguments are existing private native emitter state and resolved frame
providers. It retains no emitter, node, pointer, file, network, or rendering
resource. Godot Variant/StringName/PackedByteArray ownership is explicit. Calls
and the key cache are confined to the presentation thread; concurrent worker
kernel calls are not supported. GPU resources still publish through the existing
native scene owner on the main thread. Input errors return a diagnostic
Dictionary rather than reading unchecked offsets or substituting geometry.

The kernel preserves original Z-up/WXYZ arithmetic, float rounding/grouping,
bounded original CRT trig reduction, Quake inverse-square-root, all seven quad
modes, RGBA byte packing, atlas mutation and original 24-byte vertex records.
Godot coordinate conversion/upload remains in the existing GD surface owner.
Per-emitter GD provider calls remain outside the arithmetic kernel. Custom
replacement sine/cosine callbacks are explicitly rejected.

## Evidence and limits

`native-kernel-vertices-v3.json`: 492 checks, including all 245 original vertex
observations checked as exact uint32 words, provider calls and atlas mutations.
`native-kernel-arithmetic-v2.json`: 66 checks across seven larger batches,
prepared-atlas paths, state equality, malformed input and timing-loop allocation.
Both normal-heap CDB runs arm four native exception traps and pin all native GD,
C++, manifest/DLL and harness sources. Logs are clean, no source mutation or
trapped exception. The first experiment (`native-kernel-vertices-v1`) exposed a
registration fault and invalid NIL conversion lookup; property metadata and
conversion initialization were corrected. That failed result is retained.

`native-kernel-particles-gpu-v1.json`: 30 checks with actual torch equip-channel
flame/smoke, portal quads, authored direct/template/actor owners, private lists
and GPU meshes, shrinking surfaces and retirement. Screenshot inspected, clean
normal-heap CDB exit and unchanged source/DLL hashes.

`native-session-kernel-vertices-v1.json`: actual direct launcher with the compiled
opt-in environment, owned-local Prelude, 20 entities/nine tiles, authoritative
1.5-metre movement, finish acknowledgement, zero remaining workers, no trapped
native exception and unchanged native/host/kernel/DLL source hashes. All 129
loaded JS modules belong to the retained protocol/services dependency graph;
the render-module guard also rejects the old reference/target/lightning modules.
Some generic imported modules contain both data and legacy visual helpers;
their unused exports are not proof of complete dependency-graph retirement.
No public connection was made. The room is too small to accept dense-world FPS.

`native-kernel-reference-gpu-v1.json`: 147 scoped reference/chain checks, including
the actual original cold-ray resource and private authored moving chains. Image
inspected. This precedes later harness/build-manifest edits and its recorded
source pins are historical; it does not prove original-client pixel parity.

The 1,024-particle CPU microtest measured about 32 ms in GD versus 0.54 ms compiled
in its first run. This is an isolated arithmetic test, not game FPS.
`native-capture-kernel-vertices-v1.json` moves the same captured room's rolling
vertex cost from 28.03 ms to 2.68 ms. Settled frame intervals improve from 74.27 ms
to 43.63 ms (roughly 13 to 23 FPS), with simulation still 22.70 ms. Preparation is
17.144 seconds versus 22.225 seconds in the preceding run; cache/scheduling state
is not controlled, so this is not a cold-load speedup claim. The room remains
unsuccessful due to `ait_mscmedp_008`, and visual limitations remain. The editor
is preserved, random visual evolution differs, and capture playback is one
snapshot with live idle animation. No 60 FPS/full effects/migration acceptance.

Next work must address native simulation/initialization and remaining scene
costs, along with complete visual behavior, actual default-launcher admission,
moving protocol playback, cold/warm transitions/reconnects and frame pacing.
This kernel does not remove the retained JS networking/login/download services.
