# Area effects and multiplayer HUD — 2026-10-18

Target: installed NWN:EE89.8193.37-17 nwmain x64, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original binary/server unchanged. Full multiplayer goal remains ACTIVE.

## Incident and native evidence

User reported a summon lag spike, no summon/unsummon effects and missing eight
party-bar buttons. Passive v84 diagnostics show dropped4/2 packets at summon/
unsummon times; frozen `network-summon-incident-v84.json` retains that evidence.
There was no frame-stage telemetry in that running build, so the spike's cause
is **unproven**. No claim of a performance fix follows from missing effects.

Sender4cea60 writes WORD visual, three FLOAT1/32 positions and (8193.14+)
ObjectVisualTransformData, then4/2. Client main7a41a0 routes major4 to76d910;
branch76da53 reads those fields and passes current area+visual+position+map to
7da460 at76dc00. Static disassembly corroborates REA. Unlike5/3, this path
does NOT create a dummy creature or use CLoopingVisualEffect.

7da460 allocates CNWCVisualEffect(type11) through8720e0; constructor registers
one client INTERNAL ID/AI owner.872770 selects ONE model in order: LowQuality
(only low setting), Imp_HeadCon_Node, Imp_Impact_Node, Imp_Root_M_Node,
Imp_Root_S_Node, Imp_Root_L_Node, Imp_Root_H_Node. It reads orientation/shake,
loads part255/flags8 and preserves native special39/40/219/253 branches.
Area-add sets scene, destroy194=1, instant190=1, position, phase1, transforms.

873160 owns impact/duration/cessation audio and numeric model animation. Verified
model wrapper9b2a20 vtablee78590:48->9614b0 returns positive seconds*1000;
58->9b2ae0 maps0default/1impact/2duration/3cessation;80->9b2f30 forwards playback.
872330 AI uses unsigned SubtractWorldTimes remainder, ignores day count, updates
sound position, transitions phases and handles retirement/destruction. Retirement
also subtracts the SAME elapsed milliseconds in the frame that creates its timer.

`area_visual_effect.js` ports full loader/start/AI owners; original-code fixture
`inspect-native-area-visual.py` executes those complete functions with explicit
table/model/audio/clock/scene/allocator lower boundaries.928 cases match JS calls
and state exactly. Initial oracle runs had fixture pointer-variable shadowing,
missing operator_new wrapper and wrong mode argument width; retained failures
were corrected (native MOV DL,3 proves BYTE); oraclev6 and testv4 pass.
This is not original GPU/audio/ground-orientation or full scheduler validation.

## Implementation and rendered checks

Decoder recognizes4/2 independently of object/P/B schemas. Frontend routes it to
NetworkAreaVisualPresentation, sharing ONLY the internal client allocator with
projectiles/dummies. Canonical uint32 server proxies/effects/IDs are never added
or changed. Models use the existing reference/animation/material/particle owners.
Native AI controls impact countdown and retirement. Late loads cancel on scene
disposal. Asset I/O does not block the frontend's canonical update queue.
Nonidentity transforms, ground/special orientation, special speed/default clip,
camera shake and audio remain explicitly diagnosed rather than guessed.

Actual original-server capturev64 includes two4/2 packets: visual36 at[5,4,0]
and99 at[5.4577775,3.0140178,0]. Installed2DA selects vff_summund/vim_unsummon.
Initial GPU replayv6 exposed TWO failed bouncing emitters in vff_summund because
the scene collision provider was absent. This was a failed full-summon rendering
check despite66 vertices. Added static native polygon-hit/normal service shared
with the verified camera query. Dynamic scene collision/BSP/CHitInfo remain
diagnosed `particle.scene-collision-partial`; no invented always-miss provider.

Final isolated WebGL replayv7: actual two packets, installed models/textures,
explicit fixture floor polygons and synthetic bodies. Summon1236 peak vertices,
unsummon1266; no failed emitters for either. Both retire and release their internal
objects; canonical world identical. Cold effect load measured~2.9ms each; max
draw41ms/1.4ms in this fixture. This is NOT the full area's live lag measurement.
Existing actual potion replay, semantic point dummy expiry and cold beam endpoints
still pass. Inspected area PNG shows unsummon. CPU/SP visual206 cessation/native
controllers/Detonate/150 vertices/retirement regression passes.

## HUD

Eight original party-bar resources/order are now shared by GameUi and network
primary portrait: map, inventory, journal, character, rest, spellbook, options,
PvP. Native skins are cached by the existing NativeUiAssets; callbacks are scoped
to area/session. Inventory delegates to the existing native request owner.
Spellbook reads replicated known/prepared spells, displays remaining server uses,
allows assignment even without ready uses, and delegates ready clicks to the
existing typed cast targeter. Drag validation checks session/actor and owned
choices before quickbar assignment. No slots, spell uses, HP or actions resolved
locally. Player list and class summary read replicated state.

Map/journal/rest/options and native character-sheet details/PvP actions remain
unfinished and visibly report that when opened. Rest does NOT pretend to rest.
The new panels are behavior projections, not native pixel/layout parity claims.
Isolated installed-art HUD replayv1 verifies eight skins/click routes, inventory
delegation, real DOM spell drag->typed quickbar assignment and ready click->target
delegate, with canonical proxies unchanged. Test labels use explicit fixture text
because it has no TLK bridge. Screenshot inspected.

39 focused tests passv3; buildv2 passes (existing bundle warning). Frame-stage
durations and shader-program counts now record slow frames; model-resource
preparation over250ms is separately recorded. These establish future evidence,
not the cause or resolution of the reported spike.

At this offline milestone user v84/PID39408 and server20964 remain open, untouched.
Live acceptance/reconnect is still pending; do not claim the new build is loaded.

## Live follow-up and shader-cache correction

Normal close ofv84 saved the real user run. Its actual4/2 inputs were visual35
(vff_summon3) and99; retained in network-summon-v84-summary.json. No special
production spell/module cases were added. Model35 also uses existing Single/
Fountain/Explosion owners; camera shake remains diagnosed.

Livev85 reproduced the actual reported freeze: frame work7430ms, of which
7425ms was renderer.render, shader programs12->16. Summon phase elapsed during
that stall; only unsummon was captured. Treatv85 as FAILED summon-render timing
acceptance, despite two delivered messages/retirement and working HUD.

Three specializes lit shaders for scene-wide light counts. RendererLightSlots
adds zero-intensity, non-shadow renderer-only capacity slots; actual lights and
priorities/colors/shadows are unchanged. Capacity is based on actual counts,
kept through transient additions/removals and bounded by GPU uniform capacity.
It is shader-cache management, NOT native light selection. New capacity buckets/
new material variants still require compilation. Area compileAsync admission
was also added before areaReady, keeping DOM responsive during initial linking.
Local installed Three WebGLRenderer/WebGLProgram/WebGLLights are the source for
the specialization/compile behavior; no external library assumption is needed.

Isolated actual WebGL test:20 points/15 shadows/three Lambert material variants.
Cold baseline9024.7ms; adding two lights3.2ms, removal2.2ms; program count5->5.
Unpadded reference needed9783.8ms for different-count programs. Pixel comparison
was EXACT0 difference. Hardware budgeting retained all15 requested shadows.
Unit tests verify capacity reuse, no source-light mutation and no real-light
drops if hardware cannot fit padding. Native per-object light selection remains
a distinct incomplete owner.

Corrected interactivev86/PID43232 is OPEN on unchanged vanilla server20964.
Actual portrait radial summon and associate Unsummon generated two4/2 effects;
both have gated PNGs requiring ready received effect + positive nonfailed
particle vertices. Both PNGs visually inspected in the full module. Effects
retire, familiar returns invalid, sampleFailure null and zero runtime errors.
No frame-work>250ms or gap>750ms was logged in the summon/unsummon window.
Initial area/character model-material warmup DID still produce2.4-5.6s stalls
before that window; overall startup performance is NOT solved.

Eight buttons are visible in both full-module screenshots. Actual Spellbook
button, spell37 DOM drag->hotbar0 and panel close completed; live quickbar shows
the typed spell binding. No additional scripted inputs remain after32s; world
PNG at35s and frozen readiness confirm completion. Fullv86 report is pending
normal close; it has NOT been used as evidence. Frozen readiness/diagnostics
are safe checkpoint inputs; active live/control JSON and open stdout/stderr
MUST remain excluded. No original-client concurrent acceptance in this run.

43 focused tests PASSv5, production buildv5 PASS. Buildv4 is loaded inv86; the
post-live stale-drag/cast-error guards from buildv5 are tested but NOT loaded
in that open session. Do not reconnect it solely for those guards. Audio and
rest/map/journal/options/PvP/native sheet details remain unfinished.

SEALED area/HUD/shader checkpoint backups/multiplayer-area-visual-hud-20261018-v2.zip:14137files/347447829bytes, writer38031terminal0 consumed, every entry length/SHA256 verified. Scope14138entries/22required/0missing/0forbidden; inherits13914 unchangedtext +34 changed/new scanned/0candidates/newcredentials against audited area/HUDv1. This postsealnote/audit outsidearchive. v86/PID43232 and vanilla server20964 remainOPEN; current window visuallychecked/foreground, automationcomplete. Buildv4loaded; tested buildv5 stale-action guards notloaded. FullgoalACTIVE; nativeaudio, startupmaterialshaderadmission, MP rest/map/journal/options/PvP/sheet and concurrentoriginalclient acceptance stillrequired.
