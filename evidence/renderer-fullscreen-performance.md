# Fullscreen and camera rotation rendering

2026-10-19. This is a Three 0.180 renderer adapter; no native binary, server,
canonical object, combat, movement or light-selection policy is changed.

Observed on the owned vanilla-server session in m0q1d, original client passive:
window1440x960 has drawing buffer1084x673; fullscreen3440x1440 has buffer3100x1192.
Both use DPR1. Native networking usually takes under1ms. Stable fullscreen draw
work is CPU dominated by WebGLShadowMap's six full-scene walks per point light,
then WebGLBindingStates attribute checks/draw submission. CPU profiles156/157
retain the actual stacks. Camera rotation also changes uniform/shadow profiles:
v157 runtime observed a13707ms draw while programs43->48, plus3493/1917ms draws.
The first traversal-only rollout therefore did NOT fix rotation stalls.

RendererShadowTraversal flattens visible renderable leaves once per frame,
uses their CURRENT world spheres to conservatively reject only objects outside
each point shadow cube's far bounds, and hands actual objects to the original
shadow renderer for final face culling/drawing. Parents/children are not edited.
Nonleaf renderables are retained whole; nonpoint, VSM and type-change paths
retain original traversal. Explicit update/retry flags and disposal are tested.
No shadow texture size, shadow admission, real light intensity or output
resolution is reduced. Unbounded objects stay admitted.

RendererLightSlots now reserves native area lights outside the current view
from RendererLightSelection's existing counts, bounded by its native128 limit
and GPU uniform capacity. Point-shadow shader slots reserve available GPU
samplers/uniforms, using zero-intensity renderer-only lights and a shared white
1x1 texture. They never request shadow draws; RendererShadowBudget ignores
them. Actual authored lights, admission and canonical IDs are unchanged.
Other shadow types and exhausted budgets may still require new profiles.

Validation:23 focused rendering/keyhole/model-preparation tests and buildv4 PASS.
GPU fixturev1/v3:10 traversal comparisons at1084x673 and3100x1192 have identical
image bytes and six actual light shadow maps under movement, hiding, geometry
deformation and removal. Reference draws18-27ms versus optimized10-12ms in v3.
Six simulated camera admission changes keep one padded shader profile; all
shadow maps are byte-identical. One of six image comparisons differs in ONE
8-bit channel by ONE unit, other five exact. Failed strict v2 is preserved;
v3 explicitly bounds and reports that GLSL color-rounding difference.

Live traversal-only v157: full area77 templates prepared, zero pending/failed;
about7800 nodes/2440 casters become about1400-1750 nearby caster entries across
12-15 lights instead of repeating whole-scene walks for72-90 shadow faces.
Representative windowed draw11.6ms and fullscreen16.8-38ms, improved over
baseline45-145ms. These are observational comparisons, not identical poses:
the user moved/rotated between sessions. Shader-capacity live rollout pending.

Open: steady large-view GPU/draw cost, other light/shadow topology, new materials
and effects can still be expensive; no claim of flawless performance everywhere.
Native picking policy, radial stacking, active original-client shared gameplay
and the full multiplayer goal remain unfinished.


Follow-up: live158 (DRKDVoWS, PID636) reserves128 point/15shadow shader slots and completed16 physical camera drag steps in fullscreen with no further >250ms runtime render event during that controlled sweep. Program count25->32 changed without a measured long draw. Earlier join DID have a19233ms draw19->24, and t_door01 async preparation7176ms; this is an unresolved failure, not full performance acceptance. Native network time remained about0.5ms.

User-requested debug HUD relocation is implemented in index.html/style.css: both camera selectors, request/status text, hints and debug buttons now live in the outer inspector, unique IDs unchanged. Game viewport text cannot be selected; chat text inputs remain selectable. Build/UI source checks pass; live158 still has the old markup until a fresh launch.

Investigation found NetworkFrontend serializes world.apply and awaits NetworkScene.sync model loads. A coalesced requestSync loader and stale/deleted/disconnect guards are developed and tested (8 installed scene/transition tests pass). Main still awaits sync: enabling background loads needs a decision for combat/casting cues received before a model is ready. The experiment is deliberately not wired into replication yet.

Compact nonshadow point-light GLSL loop experiment is also NOT enabled in main. Its isolated GPU comparison launch was rejected by the automatic approval service because account usage prevented review, not because the action was determined unsafe; the action did not run. Do not route around approval. Need fresh GPU compilation/pixel checks before use. Static area shadow variants are another warmup gap to investigate. Full multiplayer goal ACTIVE.


Final scoped backup multiplayer-fullscreen-renderer-20261019-v2.zip VERIFIED61files/48996494bytes; independent Node ZIP audit verifies18parent hashes,61required files,0missing/duplicate/new credential candidates, archiveSHA256029a8d00acf6236c59a3349f92f34f69e201e4957a2f9824f89a15dffb20e68d. Node audit uses workspace-only read access; it does not retry or bypass the rejected GPU launch. Production source build BNuewpaN/CHuPTLkS includes debug-panel relocation and the tested traversal/capacity changes; compact-light GLSL and nonblocking scene loader remain unconnected experiments. Running client158/PID636 still uses older DRKDVoWS UI; no pending automated gameplay. Original33744/server20964 confirmed alive unchanged. GPU/new-client launch remains unverified after automatic approval service usage-limit failure. Full goal ACTIVE.
