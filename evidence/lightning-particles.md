# Lightning particle chains — 2026-10-18

Full multiplayer goal remains active. This increment connects the original
Lightning update and physical reference endpoint to the shared SP/MP renderer.
It does not add gameplay effects, spell resolution or server-owned IDs.

Read-only nwmain89.8193.37-17 SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
REA91238 was reused; original executables and Ghidra were unchanged. No
credentials or authentication inputs were used during this increment.

## Native owners and evidence

LightningEmitter::Update140065290..140065cca maintains a fixed particle count
from CVTTSS2SI birthrate. It calls neither chkParticleLife nor the base movement
function. Zero count or no endpoint drains active particles backwards to the
free list. Shrinking/growing preserves physical pointer order and capacities.
Recycled particles are not initialized again. Critically, the original caches
the INITIAL free-list count/index across a refill; multiple additions can
reuse the SAME stale final pointer. The port preserves these aliases. The
first JS comparison failed on this quirk and was corrected from the original
execution, rather than changing the expected output or substituting pop().

Age/atlas bookkeeping, motion-blur trails, delay accumulation, held-chain
rotation/translation, source jitter, endpoint placement, fractal subdivision
and final longitudinal jitter retain float grouping and CRT draw order.
Regeneration does not update the held-chain cache. RecursiveFractal140062460..
14006280a draws signs even below its DOUBLE .01 radius threshold and retains
its duplicate zero-span recursive calls. Its jitter uses FLOAT *.01, while
the final Update jitter uses DOUBLE *.01 followed by CVTPD2PS. Saved disassembly
confirms these distinctions and the normalization input is first-minus-last.

SetEmitterTarget1400643c0..140064596 searches DIRECT physical children in order.
The first reference child wins; it is cast twice, its referenced model pointer
is stored, distance uses current global position, and Lightning cache writes
use the emitter's cached position. The three separate Lightning casts remain.
No child causes removal of the registered target listener. Lightning Initialize
140061d30 calls base initialize, writes life1, registers _EmitterTarget, and
writes WORD age mode0. Native NewCAurObject1400931f0 dispatches _EmitterTarget
after CreateReferenceObjects and before PartInitMaterial; Gob::Append14008c0c0
also dispatches it after adding reference objects.

inspect-native-lightning-update.py executes full Update, RecursiveFractal and
actual native vector/quaternion/normalization helpers in2697 cases. CRT random
draws use the checked seeded stream; source scale, target position, allocations,
memmove and Particle::initialize are captured lower boundaries. Synthetic
particle initialization responses are explicit; independent earlier native
constructor/initialization tests cover that lower owner. Cases cover counts,
aliasing/reuse/growth/shrink, no target/source, delay equality/rotation, modes3/6,
radius thresholds, negative/zero scale, seeds, positions and random source size.
The v1 oracle failed on a fixture loop variable overwriting its synthetic source
pointer; v2 corrects that and the active-realloc return-site label. No original
code was altered. JS matches full state, pointers/order, capacities and draws.

inspect-native-emitter-target.py executes the full original callback and
Lightning initialization in97 cases. Physical casts, global pose, model position,
base init and listener operations are captured boundaries; original magnitude
executes. It proves first-child behavior, distance/cache fields, missing
Lightning cast and unregister/registration order, not full Gob construction.
The first test expected the wrong fixture count193; corrected to actual97.

## Renderer and limits

ModelReferenceScene exposes its physical part graph through a WeakMap lookup;
no circular runtime pointers enter serializable cloned userData. The particle
adapter binds the first direct reference using setEmitterTarget, then reads
that independent referenced model's live position. It does not guess by name,
distance, world objects or spell ID. Missing required reference ownership fails
visibly. A Lightning model with no reference has no endpoint and no decorative
particles, matching its native drain path. Base P2P movement is not invoked by
Lightning, so that unused flag no longer rejects this class.

lightning_emitter.js and emitter_target.js supply the native state owners.
Existing particle initialization, RNG, linked CPU vertex generation and GPU
upload are shared. Part scale comes from the existing common Part2c scene field
(node local scalar), distinct from source adjusted scale. Physical child models
remain presentation-only; no canonical uint32 or uint64 effect IDs are created.

The renderer currently projects initialization/target binding when a live emitter
is first visited. Complete Gob creation/Append/event-listener dispatch and
cache/frame ordering remain unverified and explicitly diagnosed as
particle.reference-target-scheduling-unverified. Authored/animated controller
updates still pass through the existing pose adapter; the Initialize life1
write is retained on admission. Arbitrary startup/control ordering, client RNG
seeding, attachment invalidation/scene lifetime, fog/soft-depth/gamma and native
light selection are not claimed complete. Negative or invalid subdivision
counts that would access native invalid storage raise diagnostics, not an
invented alternative chain.

## Validation

52 focused checks passv2, including all2697+97 native cases, the existing
particle/frame/initialization/vertex and shared visual/reference regressions.
Production buildv1 passes with the existing size warning. Installed SP visual206
cessation/Detonate/native controllers/150 CPU vertices/retirement passes.

Isolated Electron/WebGL replayv5 passes: three actual captured potion messages,
one explicitly synthetic point message and synthetic beam A/D presentation
events. Actual installed vim_raycold has two Lightning emitters with3/33 active
particles and12/192 linked vertices; both render without failures. Total beam
scene peak1062 vertices includes endpoint Fountain particles. The inspected PNG
shows the connecting cold beam. Source/target wrapper movement checks both
chain endpoints; removal releases the beam and both referenced models and leaves
canonical state identical. Point expiry and potion retirement also still pass.
v4 contains the initial rendered chain; v5 adds moving-endpoint assertions.
Bodies/anchors are synthetic and this is not an original-client pixel comparison
or a fresh live casting/authority acceptance run.

User interactive v84/PID39408 and vanilla server20964 remained open and untouched.
The new build is NOT loaded in that user session. Audio/other procedural owners,
full native light/event/scene services and original-client concurrent combat/
casting/playthrough acceptance remain required. Full goal remains ACTIVE.

SEALED Lightning checkpoint: backups/multiplayer-native-lightning-20261018-v1.zip,13996 files/329868750 bytes. Writer23728 terminal exit0 consumed; every entry length/SHA256 verified. Scope13997 entries inclmanifest/24 required present/zero forbidden. Credential audit inherits13760 unchanged text entries and scans63 changed/new text:zero candidates/new credentials, against audited effects/render/beam baseline. This post-seal note and audit are outside the archive. No credentials used this increment. User39408/v84/server20964 remained open and untouched; new Lightning build not loaded. Full multiplayer goal ACTIVE.
