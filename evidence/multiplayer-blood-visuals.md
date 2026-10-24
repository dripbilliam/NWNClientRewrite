# Multiplayer damage blood effects — 2026-10-19

Native model-hit damage presentation now connects SpawnHitVisuals80bb10 mode1
to separate per-creature render slots. This advances the multiplayer goal;
it does not claim complete combat or live blood-effect acceptance.

## Evidence and native behavior

Read-only NWN:EE89.8193.37-17 nwmain SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
The installed binaries, live original/server processes and Ghidra project were
not changed. No proprietary assets copied into the workspace.

Existing whole80e490 hit-callback tests establish positive signed damage,
result mask0x4aa, melee and creature-target gates. Blood direction is attacker
position minus defender position. New code connects this existing callback,
without local attack rolls, damage, effects, scripts or canonical mutations.

Whole80bb10 mode1 selector/reuse oracle:1020 final cases, including both
critical results3/10, special attack867/868, killingBlow exactly1, signed WORD
damage/max-HP thresholds, all three violence modes and an unknown mode, blood
colors/N/missing/unrecognized strings, last render override, weapon type7,
kind28 suppression, LowViolence fallback and all three finished-slot positions.
Tables, max HP, client violence, model allocation/query/destruction are explicit
services. Allocation deliberately fails, so these cases do not execute pose or
rendering. Initial696-case fixture reused its return sentinel as a destructor;
that produced invalid non-boolean results for finished-slot cases. Invalid
observations are retained separately; corrected and expanded final cases pass.

Mode1 first suppresses kind28==1, then reads appearance.BLOODCOLR. N returns0;
empty warns/returns0. WeaponAttackType7 forces violence0. White color or the
last nonzero native18/20 render override selects white variants. Native fixed
row families are R109/112/115,G110/113/116,Y111/114/117,W237/238/239. All model
names still come from active visualeffects.Imp_Impact_Node. Violence0 applies
the LowViolence redirect when found; violence2 uses direct rows. Both use
large-hit flags or signed damage < signed maximumHP/10 to select size. Violence1
uses the first row normally and second row for large hits, independent of HP.
An unknown blood string or violence setting can reach allocation with an empty
model name; the renderer diagnoses that failure instead of inventing a model.

The actor has three physical model slots178/180/188. The first empty slot or
first whose Gob::GetAnimation("impact") time is-1 is reused. Finished model is
destroyed before replacement. All-active returns1 without allocation. Completed
models remain attached until reuse or creature destruction; no guessed cleanup
timer or particle-count heuristic is added.

Native success-path oracle:380 whole80bb10 executions exercise direction,
facing, weapon types0..6, no weapon, animations0/200/201, zero direction and
default attachment part. The normalized direction is dotted with raw defender
facing, clamped only above1, then native float acos is evaluated. Normalized
facing cross original direction controls sign; defender weapon/clip adjusts
angle by pi/4. Final native quaternion is axisZ(angle)*axisX(1), not an invented
90-degree rotation. Main selector255 attaches part"impact", flags3, and plays
impact speed1/flags1/time0. Native vector normalize/cross/axis-quaternion/
multiply/acos control flow executes; tables, model, equipment, string comparison,
animation and CRT sin/cos/sqrt/FP-status/domain services are captured boundaries.
Quaternion agreement is checked within1e-6; no native CRT trig equivalence claim.

Separate whole helper oracle:2015 native float acos inputs (including endpoint,
exponent/half-value boundaries and domain cases) match exactly in the JS helper;
18 Gob::GetAnimation0510b0 cases verify first physical case-insensitive run,
duplicates, inactive lookup and negative time. Initial copied acos expression
missed the original mixed float/double steps. Assembly/constant inspection
corrected that, rather than relaxing the exact comparison. FP status/errno and
inactive model lookup are explicit lower boundaries. Native slot time includes
the terminal run until it is physically removed by the existing native run clock.

CNWCObject761760 initializes kind28=0 and native18/20 override storage empty;
the presentation uses those initial values. Later render-effect overrides remain
unimplemented and diagnosed by their effect owners, not guessed from effects or
server fields. Creature7fb140 initializes all three blood pointers null.
Weapon800c30 uses the existing native equipped-slot mapping on the DEFENDER.

Targeted read-only instruction scan locates game.gore registration6b9992 in
6ae3b0 and options construction8245f9 in823e60. Registration6b9987 supplies
default1. Multiplayer Options now exposes Low0/Normal1/Full2, used by future
hits across scene transitions. Installed user preference import and native
options art/localization remain unverified; this is an in-memory preference.
The attempted full6ae3b0 dossier exceeded response size; default evidence is the
explicit instruction-boundary window, not a claim to port its whole initializer.

## Rendering and checks

NetworkBloodVisual reserves physical slot order during async resource demand,
captures direction/facing/clip/weapon choice at hit delivery, uses active model
resources and the shared native world-pose/flags3 attachment adapter. It plays
own impact clips through ModelAnimator.playNative and reuses its native run list
for completion. Pending loads cannot resurrect removed/replaced canonical actors,
changed render bindings or disposed scenes. Creature removal/scene disposal
destroy models and forget attachments. Nonfinite pose/load/attachment failures
are recorded. Async cache/admission timing is an adapter, not native synchronous
resource-loader equivalence.

Installed GPU fixturev2 PASS: c_skel_com01/a_ba decoded inherited nwcloseh
dispatches four physical hit callbacks with a synthetic damage result; exactly
three installed vwp_m_blood_red models occupy the slots, with270 peak particle
vertices. Own native impact clips complete using their installed4.966670036s
duration. Models remain retained; two subsequent authored hit callbacks replace
the first two completed slots while preserving slot2. Creature removal destroys
all slots. Canonical actors/registry cursor remain unchanged; no failed effects
or console errors. Peak PNG visually inspected. Fixturev1 failed because its
observation window was shorter than the actual blood clip; v2 derives the window
from installed clip lengths. No production lifetime was changed to pass it.

The fixture uses synthetic actors/outcome, capsule bodies and the production
decoded inherited creature playback adapter. Its attachment nodes, effect models,
textures, own native effect playback and particles use installed data. Particle
collision/presentation approximations remain diagnosed. This is not new live
server damage, original-client pixels or complete inherited-animation parity.

43 focused regressions pass, including new async slot/canonical lifecycle tests
and existing parry/combat/audio/area/pose/HUD behavior. Buildv2 passes, retaining
the existing bundle-size warning. No broad full-suite run was needed this pass.

## Remaining

Live damage/parry verification, weapon blur/special attack effects, native robe
rendering/inherited creature scale and stacking, effect material overrides,
complete mixer, imported settings and original-origin shared active gameplay
remain open. Replacement33496/v153 still has the previous weapon-sound build;
new build7-ZgFglh has not been reconnected. Original33744/server20964 were
revalidated and left untouched; no gameplay inputs or credentials used this pass.
Active153 reports/control/interactive logs are excluded from the checkpoint.
The full multiplayer goal remains active.


## Subsequent live acceptance

2026-10-19 blood live acceptance: normalclosed153 (253203221bytes) then154 (357579204bytes,1native character export). Native buildhzqqx3l3 actuallyloaded; m0q1d ->m0q1b ->m0q1d ordinary exits/walks, weakGoblin4645 ordinarynativeattack andactualremainingWeakSkeleton4795attack. Realserver damage77->min53; originalAndorian86unchanged/passiveanotherarea. Actualblood vwp_s_blood_red28distincteventsignatures/342peakparticlevertices/retained3slots andnativecompletedruns; installedGPUv2 separately270vertices. verify-network-blood-visual.mjs PASS. Two QA scheduling/selection failures recovered andretained: prematureout-of-rangeexit, bbox-centerrightclickopenedGround instead ofcreature; Attackchoiceinjectedhelperthrowsruntime.uncaught Quickbar radial choice unavailable (exactly1knownQAerror,NOTzeroerrorclaim). Typedattackvalid; physicalradialAttack andliveparryUNVERIFIED. ReturningroomwasNOTinitiallyclear: WeakSkeleton4795attackedthere; ordinaryattackremoveditthenPCwalkedtoeast70,105,HP53stable10samples/queueempty. No bloodfailures. Newpassive155/PID2860 launchpendingreadiness; no scheduledgameplay. Active155logsfull/live/control/interactiveoutputmustbeexcluded. First154launchbadargformatfailedpreauth; equalsformretry44720succeededafterloading, no restartofliveprocess. Keyonlyencryptedone-usememory, neverfiles/env/argv/output. Nativeoriginal33744/server20964unchanged. Sourcev1backupverified59files/1027421bytes/61entries/16parents/0scope/hash/credentialissues. FullgoalACTIVE; final livecheckpointpending. Nextcoreinvestigateactualnativepicking/radiallayering (Groundwheelbehindchatobserved; productionpickingdefectnotyetproven), weaponVFX, broaderoriginal-origin sharedactiveplay.


Final live155/PID2860 VERIFIEDplaying m0q1d144tiles/position70,105/HP77 andoriginal86/queueempty/no scene failures/no moves,interactions orquickbarinputs; readyPNGinspected. Server restored77 onnativeadmission after154export53; no local healing applied or persistence-fidelity claim. RemainsOPEN/passive, exclude155full/live/control/interactiveoutput frombackups. FullgoalACTIVE; no pause or completion requested.
