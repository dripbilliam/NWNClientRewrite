# Native light admission / blank chambers — 2026-10-19

SEALED live v129 reached m0q1d and produced native player attack/damage results,
but its final playing screenshot is blank. Ten console shader errors report
MAX_FRAGMENT_UNIFORM_VECTORS(1024) overflow. The source scene had230 point lights;
neutral shader slots cannot fix a real-light count already exceeding the GPU.
This invalidates any claim of successful visual acceptance in that area.

Original NWN:EE89.8193.37-17 nwmain SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Read-only REA light-selection dossiers retain complete native owners and views;
no original binary, process or Ghidra project was modified.

Evidence: GetLightAdjustedRadius14007f480 applies radius*multiplier below1000,
and the configured color/scale adjustment branch. PrioritizeLights14007ff60
writes distance9C and priorityA0 using authored or runtime priority90, dynamic8C,
RGB68..70, multiplierA8 and node fadinglight110. It invokes illumination/shadow
sort owners14007ff40/1400801b0, which sort by the native score. Only-Gob ownership
overrides valid lights to score-1; nonpositive radius/multiplier/energy gets100000.
ControlLightsFade14007ddb0 and GetNearestLights14007f660 clamp active lights at128
regardless of the configured larger maximum.128 is not asserted to be the user's
native default setting. GetIsLightInViewVolume14007f180 checks adjusted-radius
spheres against current camera planes; native scene-height plane adjustment is
not yet connected. SetupLightsForThisPositionAndRadius140080f80 constructs its
own range/dynamic candidates, not simply all scene lights.

Scene::RenderSinglePass1400d0f10 switches normal/dynamic-only EnableLights stages;
the complete43847character retained pseudocode is in
rea-light-selection-scene-single-pass-full.json. RenderDrawBucket1400cd210,
RenderOnlyGobs call1400cfbca -> GetNearestLights, static bins and fade histories
show that one global Three light list is not the complete original renderer.

New isolated oracle executes complete PrioritizeLights and adjusted-radius
owners, original magnitude1402303d0 and its finite sqrt helper140c7d6d8..782.
Virtual candidate construction/sorts and shader settings are explicit boundaries.
864 finite cases match replacement distance/score/radius, including zero energy,
runtime priorities, dynamic/fading flags, Only-Gob and both shader branches.
This does not prove candidate lists, sorting ties, fade history or GPU pixels.

RendererLightSelection now applies view-sphere/radius admission and bounded
native-priority selection before hardware shadow/uniform budgeting. Source
lights retain their visibility, properties, parentage and identities. Layers
gate only renderer admission, restore before reevaluation, and restore on
retirement/disposal. Non-native lights remain on their existing path. Padding,
shadow allocation and shader-profile fingerprints count camera-admitted lights.
This is a partial native scene adapter: global focus is the current control
target, adjusted-radius uses the legacy shader branch, and native configurable
maximum/headlight, per-object paths, static bins, fades, scene-height plane,
native shadow selection and exact equal-score std::sort order remain open.

13 focused light/preparation checks and117 affected rendering/transition checks
PASS; build PASS. Tests cover230 in-view lights,128 admissions,15 shadows within
the1024-vector budget, source/layer restoration, movement and unchanged profiles.
The first real GPU fixture failed its no-new-program assertion because new
admission changed the shadow topology. Its stderr is retained. The revised
fixture explicitly pins its15 shadow lights' synthetic native priorities to
isolate a stable shadow profile; no production workaround was made for it.
Real GPUv2 PASS:230 source lights,128 admitted,194 padded point slots and15
shadows; five programs before/after23 transient lights, zero shader/GL errors
and zero pixel difference from removing neutral slots. First synchronous fixture
draw took13.88s; the later draw1.7ms. This is not evidence of a fast cold startup;
the client uses separate asynchronous preparation. The image was inspected.
Fresh installed-area visual acceptance is still required.

Live rollout v130/PID45724 is playing m0q1d alongside the connected original
client33744 on unchanged server20964. The actual ready screenshot was inspected:
chambers, floor, placeables and PC now render. Source232lights ->18admitted,
59outside and155zero/disabled at the later sample; zero shader/runtime errors
and failed objects. No automated gameplay inputs remain queued. This validates
the overflow correction for this view, not every camera/light topology or full
native rendering. Full report remains unsealed. Frozen render-proof and
live-acceptance snapshots are retained separately.

Reconnect also demonstrated a new persistence gap: the owned harness uploads
the original installed wizard BIC each join. Position was restored by the server,
but HP returned45->77 and the old quest key/equipped crossbow were absent, with
new preset item IDs. The product multiplayer form likewise selects a BIC for
upload; authoritative character export/download and latest local-vault reuse
are not implemented. Do not manufacture a BIC from incomplete replicated state
or claim campaign progress survives this reconnect. This is the next lifecycle
investigation; the server's own NPC/quest state was not reset.

## Fresh read-only dossiers, 2026-10-22

Target SHA-256 3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Read-only REA analysis snapshot: runtime-logs/performance-queue/native-lights-20261022.rea.
GetNearestLights at 0x14007f660 (ev_9311f36fe27bb85673db6825bd89f05907e502c1f6ab83c8158d12dfd037d74f)
checks distance <= authored radius + requested radius before SetLightGL, subject
to candidate flags and min(m_nMaxLights,128). This does not establish the configured
maximum or all live call-site membership. SetupLightsForThisPositionAndRadius at
0x140080f80 (ev_e36d4e8e89252a77fd9c26c1ff4b96d65a0318fdef31a8039dd44271eb060760)
builds a separate candidate list with nonzero RGB, positive radius/scale, radius
below 1000 and adjusted-radius sphere overlap. These refresh earlier evidence;
no light cap/attenuation implementation changed from this partial caller study.
The owned temporary analysis process was closed before GPU timing.

## Policy correction from the held-test investigation, 2026-10-22

[The enhanced-lighting method map](native-enhanced-lighting-policy.md) traces
the setting callbacks and caller routes in the same pinned binary. Enhanced
Lighting enables both gamma adjustment and fragment lighting; shader quality
is independent. Both saved native profiles have Enhanced Lighting on and
maximum lights 32. The current adapter remains a legacy-curve, global-list
partial implementation; its 128 default is not the inspected native setting.

Native enhanced lighting has a finite adjusted range and packs only enabled
lights for the shader's runtime numLights loop. Native legacy lighting lacks
that finite cutoff. Finite object/tile rejection therefore requires matching
the enhanced equations and inputs first; it cannot be applied to our existing
infinite-support lights without changing their contribution.

RenderOnlyGobs' GetNearestLights call at 0x1400cfbca is reached by the mapped
Scene::Render no-BSP branch at 0x1400ccbc8. It does not establish per-Gob lists
for main BSP area rendering. Fade lists, headlight ownership and list ordering
remain important even if a later candidate matches the configured ceiling.
No test or benchmark ran for these new findings, and no renderer policy was
promoted during the hold.
