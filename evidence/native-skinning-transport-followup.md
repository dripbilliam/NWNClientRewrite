# Native skinning transport: retained stream and upload ownership

2026-10-22 investigation; runtime integration remains incomplete. Reference is
NWN:EE 89.8193.37-17, executable SHA-256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
This is static evidence and a preparation step, not an FPS result.

The installed `inc_common` shader, read in place from `base_shaders.bif`, hashes
to `3a6f965d2eec5411b2075919e5dc0316d2ddbc783958de6c53730e94c75bfcab`.
Its position/orientation helpers at lines 789–802 transform vertices with the
bone matrix and normals/tangents with its upper 3×3. Lines 816 onward accumulate
strictly positive influences in x/y/z/w order. They do not normalize weights or
substitute the bind-pose vertex for an all-zero influence set. The accumulated
position retains homogeneous w, including the weight sum. The POSITION_VIEW
branch at lines 877–880 applies model-view before rebuilding the projection
input with w=1; the other branch projects the full accumulated vector at 892.
Normals use `mat3(m_mv)` at 883, not a generic inverse-transpose normal matrix.
These base-resource facts do not prove active server overrides or live flags.

`ExecuteSkinGPU` at `0x1400deb90` calls SetBoneMatrix at `0x1400dee43`.
Retained evidence: `backups/animations/rea-arelith-native-skin-gpu-v1.json`,
record `ev_5a701e0cfe4d1d008fa7928f2cd2e6a12e708850e96174d07a02084d6c4fd681`.
The exported wrapper `0x1400bf000` jumps to `0x1400b6950`. The static disassembly
in `runtime-logs/native-render-parity/enhanced-upload-assembly.json` shows:

- A valid unsigned slot is less than 64. Every valid call increments the bone
  generation at `0x1400b6987`, even when the matrix values are unchanged.
- The matrix transpose helper `0x14022e8f0` is called at `0x1400b69c0`; the
  result is stored at global palette `0x1414075b0`, stride 64 bytes. This is a
  distinct transport boundary after the row-major bone calculation oracle.
- SetUniforms compares its cached generation with `0x1413d2704` at
  `0x1400b9487`. For skinning state bit 0x200000 it compares all 64 matrices
  against the program's own copy, updating changed entries and the highest
  changed index. The call at `0x1400b9cd2` uploads one prefix with count equal
  to that index plus one and transpose=false; it skips the call when no values
  changed. See `runtime-logs/native-render-parity/set-uniforms-paged.json`.

Thus generation increments are not evidence of 64 uniform calls or mandatory
full-palette upload on every draw. The PE unwind ranges are physical ranges;
they do not establish complete logical CFG or dynamic branch coverage.

The native mesh header copier `0x140078ab0` transfers serialized normal offset
+0x244 to runtime +0x298 at `0x140078d14`/`0x140078d1a`. The loader at
`0x14007be10` treats this as a vertexCount×12-byte stream. Retained loader
evidence: `backups/animations/rea-camera-mesh-binary-loader.json`, record
`ev_6ba927256ccca9c9065b2aa8e7bf9c95cb9a8a42770142c22a4f3c362d25e302`.
Our parser previously validated that stream's bounds and discarded its data.
It now retains an independent Float32Array in `nativeVertexNormals`, without
basis conversion, normalization or changing the renderer's generated normals.
Three cases verify values/copy independence, prepared/worker serialization,
and absent/truncated stream handling. They passed in the 55-case focused run.

This metadata adds 12 bytes per source vertex and changes the source-derived
prepared-model cache schema. Cold/warm loading and memory must be measured.
The normal client bundle has not been rebuilt or promoted. CPU deformation,
expanded position writes and recomputed face normals still run as before.

Before a GPU replacement is accepted, test homogeneous positions and zero/nonunit
weights against original-code/shader observations; transpose and sparse palette
transport; authored normals/tangents; dynamic bounds and picking; shadows and
highlight passes; context loss and disposal. Generic Three skinning cannot be
assumed equivalent. Whole-room performance and visual acceptance remain open.
