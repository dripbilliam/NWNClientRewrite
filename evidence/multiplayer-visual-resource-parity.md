# Multiplayer model and texture comparison

Target: NWN:EE89.8193.37-17 x64, original SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The binary, existing Ghidra project and original live client are read-only.

The user's Arelith comparison shows a much larger dragon in the replacement,
different poses/clothing, blurred walls, missing sky/fog and darker lighting.
Successful entry and good steady FPS do not establish visual parity.

## Texture selection corrected

### Current validation, 2026-10-20

The user confirms robe placement is better, then reports a mounted NPC with
no horse and no chest. Captured appearance metadata identifies appearance495,
phenotype3, fieldAA4=34, armor chest57. Active server tailmodel row34 selects
c_horse2c4 (ISMOUNT=1), not a separate replicated creature. Its rider body is
pmh3; the chest correctly falls back to pmh0_chest057.

CreateTail140979d10 consumes appearance+d8 and active table+1c8 MODEL/ENVMAP;
CreateWings14097a5f0 consumes +dc/table+1d0. Both obey the equipped cloak's
HIDETAIL/HIDEWING and appearance WING_TAIL_SCALE. Cloak getter14076b6e0 names
GetCloakModelTable and reads table+1d8. Loader140999090 creates separate Gobs,
attaches to tail/wings, and uses scopes253/252. Existing appearance packet
storage maps fieldAA4/fieldAA8 into the native +d8/+dc fields. The shared scene
now instantiates these table-selected attachments with owner palettes, scope,
scale and forwarded body playback/speed. Missing resources are reported without
removing the rider; replacement/removal disposes their owned instances.

Forty-eight original CreateTail/CreateWings branch cases verify table/model
selection, zero IDs, cloak hides including nonzero values, and native scopes.
Table/string/allocation calls are captured and execution stops at model loading;
this oracle does not exercise GPU rendering, resource IO or dynamic physics.
The first capture mistakenly stopped at the refresh unload before model loading;
the corrected harness continues that call and tests the actual load decision.

The chest is ASCII danglymesh with112 vertices/220 faces; the old parser left
that type outside all triangle/material paths. Binary dangling nodes already
use the trimesh path. Native MdlNodeDanglyMesh::InternalCreateInstance1400918f0
constructs PartTriMesh before assigning the dangling vtable; Draw1400a22d0
uses the ordinary triangle/material rendering. ASCII dangling geometry now
uses that same renderer category and retains its subtype and explicit
Dangly-mesh simulation limitation. Dynamic dangling physics remains open.

Real cached integration loads c_horse2c4, restores the chest's triangle/material
path, plays pause2/walk with799 finite weighted vertices each, and removes the
mount without leaked instances. Earlier robe idle/walk/attack and helmet tests
also pass. Zero HTTP attempts.32 focused tests and production build
index-fvIQFqmV.js pass. Reconnected live visual confirmation remains required.

Evidence: native-creature-attachments-v1.json, creation-experience-mounted-
resources-v1.json, mounted-appearance-fixture-v1.json, robe-models-v7.json,
mount-focused-v4.txt, mount-native-test-v1.txt, mount-build-v1.txt and the
rea-arelith-create-tail/wing, model-part-attach, dangly-create/draw JSON artifacts.

The user confirms the inverse-bind build now gives the robe the right shape,
but the robe sits above the body. Actual offline Arelith dwarf body/robe poses
showed different root translations for the same clip. This is a separate
animation inheritance error, not a reason to introduce a placement offset.

Original FindAnimScale140050ed0 multiplies each model's +cc animation scale
while walking +a8 supermodels until the physical owner of the clip. Our old
inheritance code divided by the parent's scale, cancelling the dwarf factor
on robes that inherit the body. Position and Bezier offsets now multiply by
each child's scale; clip-owning models retain their authored values. Sixty-four
read-only original-code cases cover zero/fractional/multiple factors, absent
owners and both native clip-list scan branches. Forty-eight owned-clip cases
check production inheritance against that oracle.

Real cached pmd0_robe003/038/172 now have exactly the same root translation as
pmd0 in pause1 and walk. The equipped scene integration still passes idle,
walk and 1hslashl, helmet replacement and removal, with zero HTTP requests.
Twenty-eight focused tests and production build pass. The user must still
confirm alignment visually; palette, lighting and other equipment remain open.

Evidence: native-animation-scale-v1.json, rea-arelith-find-anim-scale-v1.json,
creation-experience-robe-placement-v3.json, creation-experience-robe-models-v6.json,
creation-experience-robe-position-focused-v1.txt and robe-position-build-v1.txt.

The subsequent live robe/helmet rollout succeeded as Yrs (PID34280), with zero
invalid messages/renderer errors. Derived equipment proof lists multiple robe
and helmet resources actually instantiated. The user's new screenshot then
contradicts visual completion: a robe folds around the shoulders and hood/head.

That revealed an older skinning approximation: inverse-bind quaternion/vector
arrays were parsed but unused. ExecuteSkinGPU1400deb90 uses node-indexed arrays
at+2f0/+300, after RenderSkinned1400e0410/GatherBones1400df000 gather rigid Part
poses. The slot map selects physical bones, with invalid-index admission and
termination at the second root0 slot. It combines current orientation with the
stored inverse orientation, and rotates/adds the inverse translation. The old
renderer applied current bone transforms alone to vertices already in the
reference pose, folding the mesh a second time.

The renderer now applies that inverse-bind composition. Thirty isolated
original ExecuteSkinGPU cases agree within2e-6, including repeated bone slots,
root termination, invalid slots, rotations and translations. Prepare and
SetBoneMatrix are captured; original quaternion/vector operations and matrix
arithmetic execute. Desktop/GPU draw submission is outside that oracle.
Shared model placement cancels in skin space; Part scale is excluded as in
GatherBones. Binary reference quaternion arrays are w,x,y,z; ordinary decoded
node orientation remains its separate disk/renderer contract.

Offline real pmd0_robe003/172 reference meshes are preserved within7.3e-7 and
5.4e-6 units respectively. pmd0_robe038 has no skin nodes, so this correction
alone does not prove every clothing variant. Real idle/walk/1hslashl, helmet
attachment/scale/item transform, removal and head restoration still pass with
zero HTTP requests.27 focused tests and the corrected build pass. The previous
finite/deforming-vertex check was insufficient to establish the correct shape;
reference-mesh preservation and original inverse-bind cases now strengthen it.

The new build awaits the user's normal client close/reconnect. Live visual
acceptance remains pending. A capture-directory-only lifecycle command in the
owned diagnostic launcher supports normal disconnect/restarts without desktop
automation on future runs. It accepts only close, with no gameplay or code.
The launcher now records explicit appearance/part/colour metadata without
names, raw packets, BICs or credentials to resolve future screenshot mismatches.

Helmet support uses CreateHead140978310: the canonical equipped item model
replaces the bare head and attaches at head_g (native string140e47994), with
appearance HELMET_SCALE_F for gender1 or HELMET_SCALE_M otherwise; missing
FLOAT entries use1. The actual cached helmet fixture resolves the base-item row
from active ItemClass rather than assuming an index. Its item curves have their
own context and cannot alias actor scope254 or left-hand component scopes.
Latest audited predecessor is checkpointv9:641 files/25835905bytes, SHA256
0799f2932d57c689ffa0ae75142a12d00723aab440f0d8712093881f122347f1;
37 parent archives and383 required files verified, zero missing/credentials.

The updated texture/scoped-transform build was admitted as Yrs in ordinary
server-vault play (own PID51344). `creation-experience-transform-live-proof-v1.json`
records first player rendering7591ms after launch, zero invalid messages and
zero renderer errors. A fresh screenshot shows sharper wall textures; the scene
still has clothing and lighting differences. This is partial live validation.

Robe support is now built. Read-only native CreateBodyParts140973de0 uses
CAPart MDLNAME/NODENAME, Parts_Robe numbered hide columns and19 rows of six
material overrides. IDs0..2 have no robe Gob. Failed hide lookups hide the body
part. Palette channel values255 retain the corresponding global material row.
LoadModel14099e790 creates a separate robe Gob at scope18 and attaches it to the
body root. Playback is forwarded to that separate animator; its clocks, visual
curves and skin remain instance-owned. Canonical IDs/ownership are unchanged.

`inspect-native-robe-part-plan.py` executes the original palette loop974570..660
and visibility branch97494d..9b5/97600a, capturing only the C2DA getter.
All912 visibility cases and152 palette rows agree.27 focused equipment,
animation, transform and scene-lifetime tests and the build pass.
`creation-experience-robe-models-v2.json` uses actual active cached Arelith
tables/PLTs/models, the production NetworkScene and ModelAnimator, and real skin
deformation. Idle/walk/1hslashl deform finite robe vertices and removal restores
the underlying parts (8 robed models vs20 unrobed); no HTTP requests occur.
Probev1 used a nonexistent attack clip and failed its fixture assertion;v2
corrects the clip name using the actual animation catalog.

Live robe rollout is pending. Physical Escape stopped Computer Use during the
normal-close attempt, and PID51344 was subsequently verified still running the
prior texture/transform build. Do not treat that screenshot as robe acceptance.
Helmets/cloaks/tail/wings, broader inherited native-pose behavior, bare-body
material differences and lighting/sky/fog remain under investigation. The goal
is active. The earlier sections below retain the preceding research history.

`AurGetImageWrapper1400e5c60` calls compressed lookup before native16-bit
and raster fallback. `CAuroraInterface::GetCompressedRaster1400f56c0`
queries winning resource table types for2073/2033/2059/3, then considers
table types2,5,3,1 in that order; format ties prefer2073 then2033.
A preferred2059 or TGA rejects compression. This is distinct from archive
precedence within a single resource type.

The replacement previously requested TGA before DDS, allowing installed TGAs
to mask server DDS replacements. ResourceResolver now retains winning table
provenance and chooses the supported model image through this native branch.
Production multiplayer selection runs in the current session's resolver and
crosses the same trusted-frame/session boundary as ordinary resource reads.
Singleplayer, runtime models, creator previews and network models share the
selector. Explicit palette/body-part PLT requests retain their own path.
Selected read failures propagate; they do not substitute another server,
archive or texture format. A fresh connection retains a fresh resolver/cache.

`inspect-native-texture-format-selection.py` executes the original selection
instructions on625 synthetic catalog cases. Exists/string copies are captured;
execution stops before allocation/decompression. All625 match the port.
This proves selection, not all native texture codecs or shader behavior.
KTX rendering uses Three's KTX1 loader. The native2059/16-bit texture codec
is still outside this model-image adapter's supported formats.

Offline active-context inspection finds5487 names with both DDS and TGA.
Examples tcn01_banner02, tcn01_bark02 and tcn01_barl02 have installed128x128
TGA and server512x512 DDS. The corrected resolver selects2033/table5.
Only metadata is saved; zero HTTP requests or native-cache reuse occurs.
Reports: `creation-experience-texture-selection-v2.json`,
`native-texture-format-selection-v1.json`.

Validation:48 focused checks, production build, and the hidden offline Arelith
15-step creator regression pass. Creator scroll retention, feat visibility/
groups, actual voice playback, human/half-orc model assets remain passing;
zero HTTP/renderer errors. `creation-experience-visual-ui-v1.json`.
The running live client51564 is intentionally unchanged, so a new live visual
comparison is still required after rollout.

## Model transforms: implemented; live acceptance pending

Wire reader973160 reconstructs a complete keyed map; its first key vector is
consumed and discarded, not a delta-removal list. Leaf972c70/973450 stores
ten64-byte curves. Existing decoded property names are misleading: `type`
is timer type, `duration` is interpolation type, `target` is ValueFrom,
`parameter` is duration in seconds, and `value` is ValueTo.

Client766960 copies the map to object+138 and calls model-context virtual+a8.
RTTI/vtable lookup identifies CNWCAnimBase and derived parts/head/wield/item
contexts; their+a8 target is968190. That adapter assigns scope0 or identity
to the root Gob, assigns other nonzero signed scopes<256 through model lookup
virtual+10 with BYTE scope, and resets previously assigned absent scopes.
This is not an arbitrary multiplication of all map scopes.

Gob095890 copies the leaf curves; GetAdjustedPosition08e2c0 rotates the
translation by base orientation before adding base position. Orientation
08e200 calls native YawPitchRoll22f6d0 and quaternion composition. Scale
08e390 samples ScaleX and multiplies Gob+49c; Render0a4280 uses uniform
scale and attachment ancestor scale. Scene bucket0c38f0 is separately retained.
The native curve Lerped2e9a80 includes types0..7 and calls Progress2e9cd0;
existing save/load owners already model native timers/repeat behavior.

Further model lookup targets: base964690 (scope255/root); parts99e6bc ->
99da20 plus robe18; head99b174 (254/head); wield99c5b0 (244..251 hand
component remaps); composite item9a4c8c (251..254 components). Trace those
owners and validate quaternion/clock behavior before connecting the renderer.
The renderer now consumes these maps on creature, door, placeable and ground
item instances. Root/head scopes and native held component selectors use
separate model groups; absent scopes reset, including root alias behavior.
Translation is local to base orientation, rotations use native yaw/pitch/roll
axis order, and scale is uniform ScaleX as the checked Gob path uses. Weapon
attachment scale retains the ancestor root visual scale. Canonical IDs,
positions, inventory ownership and collision data remain unchanged. Pure
visual item-map updates no longer rebuild the mesh/character hierarchy.

The pre-existing asynchronous native curve load/save API and synchronous
render API now execute the same generator-based clock/progress owners. This
avoids Promise/microtask work for every render channel. Render interpolation
covers0..7/unknown, both native timer domains and repeat/endpoint mutations.
AnimationSpeed is sampled on playback; the native run path receives it through
its playbackScale provider, and decoded clip playback supports zero/reverse.
The broader decoded clip loop/event behavior remains a presentation adapter.

`inspect-native-client-visual-transforms.py` executes87 scoped adapter cases
and630 interpolation branches. Lookup/Gob assignment and host sinf/cosf/asinf
are captured. `inspect-native-gob-adjusted-pose.py` executes120 native pose/
scale cases with original quaternion/vector operations, capturing only host
sinf/cosf. Pose comparisons allow3e-6; interpolation allows2e-6 relative error.
This does not claim original CRT transcendental bit identity. Existing native
clock/progress golden cases also pass for the new synchronous driver, checking
owned bytes, call order and repeated endpoint/clock changes exactly.

52 focused model/animation/attachment/loading/texture tests and the production
build pass before live rollout. Offline cached Arelith c_drggreen has42 clips,
including cpause1, and pmo0 has251; absence of that dragon clip is therefore
not a sufficient explanation for the screenshot's pose. Actual actor scale/
clip metadata and a fresh screenshot are still needed. No Arelith, creature ID
or spell special case has been introduced. Robe, tail/wing and other worn-model
attachments, per-part palettes, inherited native-pose rendering and lighting
remain open. Network world-pause synchronization remains a separate owner;
the transform code respects the supplied WorldTimer's existing pause state.

## Lighting remains open

Network scene lighting currently selects the sun profile whenever nonzero,
without native time interpolation. Sky/fog are absent. Do not compensate by
hardcoding brightness. Trace the active area/time flags and native renderer
before changing these. Lightmap layers, authored normals and environment/
material shader handling also need a comparison, rather than assuming every
visible difference is a missing texture.
