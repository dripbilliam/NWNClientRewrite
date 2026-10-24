# Native enhanced lighting: static method map, 2026-10-22

The goal remains incomplete. This investigation ran no game, CPU test suite,
rendering fixture, native-code oracle or benchmark. Testing is held by the
user's latest instruction. No Arelith connection, runtime inspection, native
database modification or production renderer change occurred. The source-only
alpha/keyhole candidates described below were prepared before this hold.

Target: NWN:EE 89.8193.37-17, x64 nwmain.exe, SHA-256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The executable and installed shader assets were read in place. Compact native
dossiers and source hashes/line anchors are retained under
`runtime-logs/native-render-parity/`. Original shader resources are not copied.
Pseudocode is decompiler output; the listed call sites are checked in assembly.

## Settings control separate policies

`graphics.lighting.enhanced`, rather than the name of the shader quality
preset, selects full dynamic lighting, gamma adjustment and fragment lighting.

| Setting | Registration / callback route | Observed effect |
|---|---|---|
| Enhanced Lighting | Key reference `0x1406b18dc`, registration call `0x1406b1906`, callback table `0x140e2b158` slot +0x10 -> `0x1406bd260` | Writes FullDynamicLighting at `0x1406bd270`; calls global integer parameter 1 at `0x1406bd276` and parameter 0 at `0x1406bd284`, both using the boolean value. |
| Shader quality | Key reference `0x1406b1aa9`, registration `0x1406b1ad5`, callback table `0x140e2b190` slot +0x10 -> `0x1406bdf40` | Exact names Performance / High Quality map to 1 / 2, other values to 0; calls integer parameter 7 at `0x1406bdffc`. Does not write parameters 0/1 or FullDynamicLighting. |
| Cutoff range multiplier | Key reference `0x1406b1cb3`, registration `0x1406b1cdf`, table `0x140e2b1c8` slot +0x10 -> `0x1406bc6b0` | Converts the double to float and tail-calls float parameter 0x12 at `0x1406bc6bd`. |
| Maximum intensity | Key reference `0x1406b1e78`, registration `0x1406b1ea4`, table `0x140e2b200` slot +0x10 -> `0x1406bc960` | Float parameter 0x14 at `0x1406bc96d`. |
| Intensity at range | Key reference `0x1406b1f5e`, registration `0x1406b1f8a`, table `0x140e2b238` slot +0x10 -> `0x1406bc910` | Float parameter 0x13 at `0x1406bc91d`. |

Validation: `lighting-config-registration-assembly.json`,
`full-dynamic-lighting-writer.json`, `shader-quality-handler.json` and
`lighting-*-handler.json`. The whole registration function `0x1406ae3b0`
exceeded the Ghidra response buffer; a hash-gated read-only Capstone script
retains bounded contexts around provider-established string references instead.

`GLRender::SetGlobalShaderParami` at `0x1400b71d0` writes the integer array
`0x1413d2810` only when the value changes. Mask 0x587 for indices below 11
sets shader reload pending (`0x1400b71f3`), then increments the shader-constant
generation (`0x1400b71fa`). The float setter at `0x1400b71a0` writes array
`0x1413d2760` and increments the generation only on change; it does not set
the same reload flag. The API wrapper `0x1400bf140` jumps to this float setter.
Validation: `global-shader-int-setter-body.json`, `global-shader-float-setter.json`.

`LoadAndCompileSingleShader` at `0x1400b42d0` constructs the shader prefix at
call `0x1400b446d`. Assembly, including stack varargs omitted by the decompiler,
maps integer 0 to GAMMA_CORRECTION, integer 1 to FRAGMENT_LIGHTING and integer 7
to SHADER_QUALITY_MODE. `GetMaxLights` is called at `0x1400b43e7` for
MAX_NUM_LIGHTS. This is separate from the old MAX_LIGHTS=8 compatibility define
in inc_common. Validation: `native-shader-compiler.json`.

Both saved native Documents profiles have Enhanced Lighting enabled and
maximum lights 32. The ordinary profile has shader quality Performance; the
`.0` profile has High Quality. The ordinary profile also records cutoff range
multiplier 2, intensity at range approximately 0.2 and maximum intensity 1.5.
These are stored options, not proof of the exact running configuration that
produced the user's native FPS. Preset metadata separately maps Minimal to
Enhanced Lighting off / 8 lights, Performance to on / 16 and High Quality to
on / 32. An explicit saved override can differ from its preset.

**Correction:** a Performance shader-quality name alone does not justify using
the native static vertex-light baking path as the explanation for its speed.
That path is real when FullDynamicLighting is off; the inspected saved profiles
enable the other path. A current native runtime/profile match remains deferred.

## Enhanced lights have finite support

`SetLightGL` at `0x140080c10` reads global integer 0 at `0x140080df6`.
When enabled, it checks the light view volume (`0x140080e06`), obtains adjusted
color (`0x140080e1a`), converts the faded color from sRGB (`0x140080e4e`),
enables the slot (`0x140080e55`), obtains adjusted radius (`0x140080e6e`) and
writes property 4 (`0x140080e97`). Its alpha component is radius squared,
negated for an ambient-only light. View rejection disables the slot at
`0x140080ea0`. The legacy branch still writes the quadratic coefficient
9/(2*max(radius,0.1)^2), with its own enable path at `0x140080ea9`.
Validation: `nativeSetLightCurrent.json`, evidence
`ev_00ada17410388827f13bcbc8e5390b55372fa96378292c72c6118a7edd7d7772`.

`GetLightAdjustedColor` at `0x14007f380` normalizes RGB by its maximum when
that maximum exceeds 1, the authored radius is below 1000 and parameter 0 is
enabled. It returns a Vector through the hidden result pointer; the decompiler's
one-argument signature is not an ABI specification. `GetLightAdjustedRadius`
at `0x14007f480` multiplies radii below 1000 by the light multiplier, then under
parameter 0 by the RGB maximum if above 1 and float parameter 0x12 (getter call
`0x14007f4ee`). Radii at/above 1000 bypass that adjustment. Validation:
`nativeAdjustedColorCurrent.json`, `nativeAdjustedRadiusCurrent.json`.

The base inc_lighting shader, hash
`249d4f9e2dfcdafb8918d0e6c33403fd1e9fbcbf25d83fd0b58f49e4e3266576`,
reads the absolute alpha as squared range (line 321) and returns when squared
distance exceeds it (326). Inside the range, with q=distanceSquared/rangeSquared,
its attenuation is (1-q)/(lightMaxIntensityInv + lightFalloffFactor*q)
(329-333). The alpha sign selects ambient versus diffuse accumulation (434).
The legacy branch (338) instead uses the reciprocal quadratic expression with
no finite range cutoff. Source inspection does not establish active module,
HAK or override shader precedence; that must be checked for a matched scene.

The current replacement `model_light.js` explicitly implements the **legacy**
attenuation branch. Its negative decay marker prevents finite-range rejection
in `point_light_grid.js`. Static review found that two disabled experiments,
`renderer_point_light_buffer.js` (also used by the packet experiment) and
`renderer_zero_light_work.js`, incorrectly used the positive authored radius
as a finite cutoff for those legacy lights. Both guards have now been corrected
to retain negative-decay tails. New direct/packed CPU cases and a native-legacy
mode for the existing GPU fixture are written but **unexecuted during the hold**.
The previous authored GPU results did not establish legacy-adapter coverage;
they do not validate these corrected sources. Production stays unchanged.

Conservative fallbacks are necessary for today's infinite-support math. They
must not simply be removed while retaining that curve: it would alter visible
light. A finite-support enhanced candidate needs its own complete equation and
input mapping before spatial rejection is permitted.

Inference: matching the native enhanced curve and range creates a principled
finite support for conservative object/tile/cluster light lists, rather than
introducing an arbitrary nearest-light cutoff. This could reduce work and
improve lighting parity. It is **not a measured speedup**, and switching the
curve alone is not sufficient for matching colors, ambient/material equations,
gamma/output, light fades or the complete captured room.

SetUniforms at `0x1400b8380` also derives enhanced falloff uniforms from float
parameters 0x12/0x13/0x14. ConnectShaderData resolves lightFalloffFactor at
call `0x1400ae48c` into program+0xae0 (`0x1400ae498`) and
lightMaxIntensityInv at `0x1400ae4a5` into +0xae4 (`0x1400ae4b1`).
The enhanced branch calls the unnamed math helper `0x140c7c810` at
`0x1400b8d12`, `0x1400b8d2f` and `0x1400b8d68`, using the float constant
-2.2 at `0x140d8c5b0`; its body has power-like log/exp processing. Treat its
precise powf/exception/rounding semantics as inferred pending a permitted
original-code oracle. Do not replace these uploads with guessed reciprocals.
Validation: `nativeConnectShader.json`, `set-uniforms-paged.json`.

## Effective loop length and dirty ownership

EnableLight `0x1400b3330` and DisableLight `0x1400b0550` change a slot's enabled
byte at array base `0x141405190` +0x44, stride 0x48. They increment light-state
generation `0x1413d26fc` only when that enabled state changes. The increments
are at `0x1400b3353` / `0x1400b0573`. This generation is not itself a light count.
Validation: `enable-light-current.json`, `disable-light-current.json`.

SetUniforms compares the program's cached generation at program+0xc with that
global (`0x1400b91c1..0x1400b91d4`); unchanged generation and no forced refresh
skip this block. Otherwise it scans the configured maximum, skips disabled
slots (`0x1400b9282` / `0x1400b9286`) and packs enabled values contiguously.
Only an enabled slot increments R14D (`0x1400b92e8`). It uploads that actual
count through call `0x1400b9314`, and uploads the arrays with the same count
at `0x1400b932e`, `0x1400b9348`, `0x1400b9362`, `0x1400b937c` and
`0x1400b9392`.

The count location is program+0xad0, established by ConnectShaderData's
numLights lookup at `0x1400ae40f` and store at `0x1400ae41b`. The base
inc_lighting shader declares numLights at line 34 and loops to that runtime
count at 431, not to the maximum array capacity. Thus unused capacity is not
equivalent to an enabled neutral light on the native path.

Our normal Three light loop still expands to NUM_POINT_LIGHTS. The separate
compact-loop experiment retains NUM_POINT_LIGHTS as its bound. Earlier UBO,
per-object packet and zero-term experiments already exist and have measured
limitations; this finding does not turn those rejected variants into new wins.
Deferred work should isolate active-count savings from UBO transport, per-draw
list construction, sampler indexing and curve changes.

## The main area path is not the no-BSP path

The LightManager vtable `0x140d85f70` maps +0x08 to PrioritizeLights
`0x14007ff60`, +0x10 to EnableLights `0x14007e890`, +0x18 to
EnableLightsDynamicOnly `0x14007ea70`, +0x30 to UpdateLights `0x140081100`,
+0x38 to SetupLightsForThisPositionAndRadius `0x140080f80` and +0x60 to
ControlLightsFade `0x14007ddb0`. ManageSceneBSP calls the +0x08 priority route;
the enhanced RenderSinglePass path enables the resulting light list.
ControlLightsFade bounds admission by min(configured max,128), maintains fade
state and can reserve headlight slots. Its SetHeadLightProperties call is
`0x14007e631`, SetLightGL `0x14007e687`, and remaining-slot DisableLight
`0x14007e6d1`. A replacement ceiling alone does not reproduce that history.

RenderOnlyGobs `0x1400cf9b0` really does call GetNearestLights at
`0x1400cfbca`. But Scene::Render checks its BSP pointer at `0x1400ccba5`,
branches to the ordinary BSP path if present (`0x1400ccbad`) and invokes the
RenderOnlyGobs virtual slot +0x270 at `0x1400ccbc8` on the no-BSP branch.
RenderDynamicGeometry `0x1400ce110` on the mapped area path draws buckets 2/3
at `0x1400ce298` / `0x1400ce2b6`; it does not itself obtain a per-Gob nearest
list. Validation: `scene-render-dossier.json`, `render-only-gobs-current.json`,
`render-dynamic-geometry-current.json`, `control-lights-fade-current.json`.

**Correction:** the known per-Gob light call does not establish per-object
light selection for the captured main BSP room. Other indirect callers and
material-specific behavior remain possible; absence from this route is not
proof of absence throughout the engine.

## Deferred work and current limits

The [test plan](native-rendering-parity-test-plan.md) now specifies independent
legacy/enhanced shading, light-count transport, cutoff boundaries, color/radius
adjustments, shader specialization and ownership checks. All new cases are
unexecuted. No full-room FPS, native runtime configuration, exact enhanced
pixels or static-bake performance has been established by this investigation.

Source-only `RendererOpaqueAlpha` and inactive-keyhole specialization were
prepared before the hold; their 16 CPU checks passed then. Both remain disabled
and disconnected from the normal client. Their GPU/image/full-room acceptance
is pending. The previously measured spatial visibility candidate also stays off
after its regression. The normal main/dist build is unchanged.

## Continued static trace: upload color and material boundaries

Retained REA `backups/animations/rea-network-light-color-space-v2.json`
(evidence `ev_fa33348a8a61f2bcc33db236629b8238b01adaf5efdafdd107b944889aecffa9`)
establishes GetColorSpaceFromSRGB at `0x1400beb90`, the global parameter-0
query at `0x1400beba2` and color_pow call at `0x1400bebb6`. Fresh read-only
disassembly in `enhanced-upload-assembly.json` follows color_pow
`0x1400bf3e0`: only channels strictly above zero and not exactly one call the
power-like helper (`0x1400bf40f`, `0x1400bf431`, `0x1400bf454`). Nonpositive,
unordered and unit channels bypass it. The exponent loaded by the caller is
the float32 2.2 at `0x140d8cd0c`. This differs from Three's piecewise sRGB
conversion; it is not a clamp of negative CPU-upload channels.

The four-component conversion target `0x1400beb50` uses the same three-channel
color_pow call at `0x1400beb76`, then copies all four components unchanged at
`0x1400beb86`. Alpha is not gamma-converted. SetUniforms' material-generation
comparison is `0x1400b9ce6..0x1400b9cef`; material ambient, diffuse, specular
and emissive conversions occur at `0x1400b9d1e`, `0x1400b9d55`,
`0x1400b9d8c`, `0x1400b9dc3`, respectively. Their program locations are
+0xab0, +0xab4, +0xab8 and +0xac0, resolved by ConnectShaderData calls
`0x1400ae4be`, `0x1400ae4d7`, `0x1400ae4f0`, `0x1400ae509`. These facts
do not identify every material-state invalidation or active custom shader.

The CPU upload operation must also remain distinct from base shader
ApplyColorSpace: inc_common lines 643-687 implement signed powers of absolute
RGB and preserve alpha. inc_standard converts the main texture at line 243,
reverts output RGB at 342, then applies fog. Three 0.180's Lambert shader also
places fog after output conversion; no fog-order mismatch is established here.
The transfer functions and full postprocessing configuration still need matching.

Base inc_lighting independently weights ambient by materialFrontAmbient (517)
and diffuse by materialFrontDiffuse (530), includes emissive (533), applies a
constant-light floor (559-565) and clamps the final light total only in the
legacy gamma-off branch (581-583). The current main.js buildMesh uses diffuse
and self-illumination with MeshLambertMaterial; parsed ambient/specular/shininess
fields are not connected there. Thus changing only native point-light falloff
does not establish material or overall color parity. Texture formats, overrides,
shader flags, specular/environment features and postprocessing stay in scope.

The static property setter trace follows wrapper `0x1400bf190` to
`0x1400b7320`. Enhanced property4 is stored at slot+0x34, slot stride0x48;
its four scalar comparisons at `0x1400b7389..0x1400b73bf` skip unchanged
values and treat unordered comparisons as changed. Changed properties increment
the light generation at `0x1400b757c`. A candidate cache must preserve this
behavior rather than ignoring animated colors, fades or signed range changes.
These physical disassembly ranges come from PE unwind metadata, not a claim
of complete logical CFG coverage or runtime observation.

`src/native_light_upload.js` is a disconnected preparation of the mapped CPU
color/range/property/falloff equations. It preserves observed float32 operation
and comparison ordering and requires an explicit power callback. It includes
no native admission, fade history, area-light/headlight handling, shader binding,
material shading or runtime integration. Seven cases in
`test/native-light-upload.test.js` passed after the user lifted the testing hold. Stub power
callbacks verify data flow, not actual native CRT power or GPU results. A later
original-code oracle and complete GPU/client acceptance are mandatory before
promotion. Seven passing CPU cases establish only their stated data-flow scope;
the native CRT and complete GPU/client acceptance remain unverified.
