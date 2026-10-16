# Particle emitter decoding and frame owners

Target remains read-only NWN:EE89.8193.37-17, executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
All captures below are under backups/animations. No installed assets copied,
original install changes, injections or Ghidra project edits.

## Active data inventory

`audit-visual-presentation.mjs` reads active visualeffects/progfx and referenced
model metadata. Prelude resolves10,100 physical visual rows,496 unique models;
410 models contain emitters. Seven model references fail (six missing stock
resources and one malformed model header); names/errors are retained in
`visual-presentation-active-audit.json`. No geometry, textures or shader bytes
are stored. Duration-program counts: Type1=6,3=18,4=34,5=25,6=38,13=1,
no duration program=275. This is a capability inventory, not a spell or
campaign completion metric.

## Binary fields and controllers

Full ReadBinaryNode14007abe0..14007b6bb dispatches flags5 to the emitter
branch14007b13f..14007b28a. Its216-byte extension has deadspace/blast radius/
length floats, x/y grid and spawn type DWORDs, update/render/blend strings32
bytes each, texture64, chunk name16, twosided/loop DWORDs, render orderWORD
and final flagsDWORD. Full base reader14007b6c0 follows; the current decoder
preserves all these fields. `native-binary-node-dispatch.txt`.

MdlNodeEmitter::InternalParseField14009a030..14009db89 independently names
each field and39 scalar/vector controller semantics. The complete assembly
(`native-emitter-parse-and-instance.txt`) confirms each controller ID, including
the high-range midpoint/percentage fields. `mdl_emitter.js` implements the
original piecewise serialized-to-runtime relocation. In this target raw448
is alphamid,452 colormid,464 percentstart: other readers' newer constants
must not substitute for this executable's mapping. Native flag setters
140061a40..140061ae8 establish p2p1,selection2,wind4,tint8,bounce16,random32,
inherit64,inheritvelocity128,inheritlocal256,splat512,inheritpart1024.
`native-emitter-flags.txt`, `native-emitter-splat-tint-flags.txt`.

`inspect-native-binary-emitter.py` runs the complete original dispatcher and
base reader for three profiles containing55 controller IDs, with captured
allocation/memcpy/As-node queries. Payload scalars, strings, flags and all
relocations match the decoder tests. `native-binary-emitter-observations.json`.
Binary FPS128 stays emitter.fps, not mesh alpha. ASCII and binary parameter
curves are now retained and sampled into independent local node state
`userData.mdlEmitterProperties`, including rest restoration. Detonate's
non-numeric255-column records remain explicitly unsupported.

The concrete vce_positive cessation model from the prepared spell fixture now
decodes as one dummy and three emitters with four authored curves. Their update
types are Fountain/Fountain/Explosion. They are not activated as gameplay
particles yet; optional decorative previews remain explicitly approximate.

## Lifetime and Fountain scheduling

`particle_lifetime.js` ports complete chkParticleLife140065f10..1400660bf.
It tests age before adding frame delta, retires on the following call after
crossing lifetime, scans backwards, retains list capacities, appends retired
particles to the free list and detaches chunk instances at virtual+90.
Negative age clamps to zero and clears native field48. Finite/unordered
comparison behavior follows COMISS/JB. The native oracle executes the full
original function with allocator/memcpy/chunk callbacks captured:
290 profiles match, including expiry boundaries, reverse deltas, capacity
growth and a chunk callback changing lifetime during traversal.
`native-particle-lifetime-observations.json`, `native-particle-lifetime-v1.txt`.

RTTI identifies PartEmitter/Fountain/Explosion/Single vtables140d84400,
140d84518,140d84630,140d84748. Update at offset100 resolves to Fountain
140064b30..140065281, Explosion1400647c0..140064b29, Single140065cd0..
140065f05. `native-emitter-vtable-methods.txt` includes the next locator at
offset110; that final entry is not a virtual function.

`fountain_emitter.js` ports the complete Fountain owner, calling the lifetime
port and explicit lower particle providers. It preserves source-factor lookup,
trail/rotation ordering, one-step angle wrapping, movement-before-birth,
temporal accumulator's integer remainder/discard behavior, spatial emission
positions/debt, free-list LIFO reuse, separate constructor and initialize calls,
and active-list capacity growth. The original function executes unchanged
alongside full native lifetime in165 profiles, with constructors, initialize,
source factor, movement, randomization and list/heap helpers captured.
`native-fountain-update-observations.json` matches exact float32 outputs and
call/list ordering, including an initialize/randomize-side accumulator change.
These lower synthetic responses are explicitly not actual particle motion or
whole-emitter/render acceptance.

## Initialization, math and standard movement

particle_initialization.js ports ctor140060680, initialize140066450..140066685,
randomPosition140068d80..140068ed2, randomDirection140068800..140068d73,
inheritVelocity140066140..1400663c4 and chkRandom1400660c0..14006613a.
particle_math.js preserves float32 grouping and runtime w,x,y,z quaternion order.
Position step is.0001, speed step.01, jitter threshold double.01. Small extents
still consume sign draws. Camera deadspace corrections reuse the original
orientation/axis. The original-code oracle executes these owners and actual
quaternion/vector helpers and embedded CRT SSE float/double trigonometry with
CRT rand and IEEE float32 sqrt boundaries. All876 profiles match exact state
and RNG, including3 deadspace cases/6iterations. Double cosine is an explicit
provider for nonzero deadspace; default float trig retains CPU-path ambiguity
checks. Captures native-particle-initialization-observations.json and
native-particle-initialization-v2.txt. Large/nonfinite/startup CPU policy open.

particle_movement.js ports Standard140068010..1400687f9: inherited/local/part
transforms, source references, wind, inherited velocity damping, gravity,
collision/reflection/damping/stopping and chunk pushout. Quaternion unary minus
flips w only. Full assembly continues after chunk free/ignore-list maintenance
where Ghidra misleadingly truncates. 384 original profiles execute actual
rotation/RotationArc/normalization helpers with explicit scene/wind callbacks;
all float32 fields/callback ordering match, including antiparallel/zero normals.
Captures native-particle-movement-observations.json and
native-particle-movement-v2.txt.

fountain_particle_providers.js composes real helpers with Fountain/lifetime.
Missing chunk/camera/scene services fail explicitly; particles allocate no
canonical IDs or server RNG. Coupled original-code oracle runs real scheduling,
lifetime, construction, initialization, position/direction/frame and movement
for27frames/3seeds, including expiry/reuse. Actual Gob::GetAdjustedScale14008e390
and constant LerpFloat fast path execute. Heap/list, CRT rand, sqrt and HitInfo
clearing are captured boundaries in this no-wind/no-collision fixture. All
intermediate states and RNG/allocation/reuse match. Captures
native-fountain-physics-observations.json and native-fountain-physics-v1.txt.
This verifies coupled CPU physics, not GPU or whole-model acceptance.

## Remaining owners

- Outer AnimateParticles140061210 is now ported in particle_frame.js;800
  unchanged original executions match visibility gates, clamped time, history,
  inherited transforms and all9 basis components. Original AsMdlNodeEmitter
  executes; world transform and Update are explicit lower boundaries.
  native-particle-frame-observations.json / native-particle-frame-v1.txt.
- Explosion1400647c0 and Single140065cd0 complete updates now ported in
  burst_single_emitter.js;647 original runs match state/list/callback ordering.
  Includes Explosion's scale1 for reused particles, point-source wind command,
  detonate latch/reset, Single construction without second initialize, looping
  age and destruction (not free-list recycling). Lower constructor/motion/
  WindManager services remain explicit in these owner tests.
  native-burst-single-update-observations.json / native-burst-single-update-v2.txt.
- particle_vertices.js ports the CPU shared RenderStandard/Linked/MotionBlur
  owner140062900..14006416c. All seven modes match245 original generated
  24-byte vertex streams, packed colors/alpha, widths, ribbons/trails, atlas
  frame/time mutations and softness parameter. Native quaternion/vector/clamp/
  fast_rsqrt/trig helpers execute. GPU/material/source-light lookup/floorf are
  captured boundaries. Original stubs1400643b0,140064170,140064180 all jump to
  this owner. native-emitter-render-complete.txt and
  native-particle-vertices-observations.json / native-particle-vertices-v1.txt.
  This verifies CPU draw inputs; no GPU pixel/shader acceptance yet.
- Setup140061d80 still pending. Full assembly in
  native-emitter-defaults-and-frame.txt, including ctor140060420. Controller
  defaults mostly0; blurlength1. Live model/scene adapter remains open.
- Per-particle move140066690..14006693d, P2PBezier140066940 and P2PGrav140067340.
- Animation events/detonation delivery, visual phase lifecycle and sound/
  impact/cessation remain open.
- Source time interpolation, CRT startup dispatch and client visual RNG seeding
  remain distinct from authoritative server state.

## Validation and limits

1,462 tests and production build pass (`model-events-full-tests-v1.txt`,
`model-events-build-v1.txt`). Focused results: `emitter-parser-focused-v2.txt`,
`emitter-lifetime-focused-v1.txt`, `fountain-update-focused-v1.txt`.
Rendered prepared Light/inventory/F2/item-wheel regression remains checked
after the shared parser/playback changes: `emitter-parser-item-ui-v2.txt` passes
against the completed build, with no engine/browser/visual load/update failures.
All other diagnostics remain in live-item-targeting-ui.json. The actual Light path is described in
procedural-light-presentation.md. The newly ported Fountain/lifetime owners
are now connected to instantiated models by model_particles.js. Templates keep
only serializable metadata; each live clone owns particle/GPU state, and removal/
area disposal cleans it up. Client RNG is separate from server/game IDs; startup
seed/order parity remains open. Missing selected services fail with one recorded
diagnostic; no decorative fallback is substituted. Main still offers a separately
labelled optional preview, disabled in acceptance. Basic shader draws packed
vertex color times active texture with native source/destination alpha blend,
depth-mask and cull policy. Native soft-depth/fog/gamma remain diagnosed.

Rendered installed vce_positive cessation clip now visibly emits its two
Fountains (`model-particle-rendered-v2.txt`, live-model-particles.json/png).
The first capture had populated buffers but invisible particles: conjugating the
camera quaternion like a model node incorrectly turned its facing axis into up.
The adapter now converts camera world basis on the left only; a regression checks
triangle normals across camera rotations. The rendered test compares changed
gold pixels inside the viewport crop with the pre-play frame (857 pixels in
the captured run), excluding interface colors. Reload clears all active state.
The later model-event-particle-rendered-v1 test adds the actual authored
detonate event and now renders the Explosion too (7+7 Fountain particles and
5 Explosion particles in the captured frame,5507 changed gold pixels). Its
reload check restores all active counts to0. No gameplay impact/cessation phase
or full spell/combat/campaign completion claim.

## Model event delivery

model_events.js ports full AnimateEvents14004fce0..14004fe88 and
Gob::DoEvent140050d50..140050eaf. Physical event order, forward (from,to],
reverse [to,from), wrap sentinels +/-1e9, reverse listener registration order,
ASCII case-insensitive names, leading-star/empty wildcard, explicit payload
override and active dispatch handle cleanup follow the original. Detonate
140061a30 writes only BYTE+108. Full creation1400621f0 registers this callback
on the source only for Explosion. The oracle executes scheduler+dispatcher+
actual detonate together for304 profiles. Heap/realloc, ASCII CRT stricmp and
test callbacks are boundaries; destruction callback invalidates handles but
does not prove the entire Gob destructor. native-model-events-observations.json,
native-model-events-v2.txt and native-model-animation-events.txt.

ModelAnimator installs instance-scoped Explosion listeners and emits events
after applying that frame's pose; the particle adapter consumes the pending
command before native Update. Unknown selected handlers remain recorded.
Full native Animate14004dbd0 clock/blending/event0 startup behavior and other
handlers are not yet claimed. Current forward preview update supplies the
checked range helper with previous/current wrapped time. Other procedural
phases/upper animation modes still need their original owners.
