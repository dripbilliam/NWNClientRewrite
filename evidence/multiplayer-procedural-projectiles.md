# Data-driven procedural projectiles — 2026-10-19

Progress toward the active full multiplayer goal. Type10 progfx projectiles now
share the native-derived client path, animation, impact, internal-ID and cleanup
owners. Spell/feat/module/visual IDs are not special-cased. Combat, casting and
all presentation are not complete.

Read-only target NWN:EE89.8193.37-17 nwmain SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a;
nwserver98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6.
No original-process injection, patch, Ghidra edit or copied proprietary assets.

## Finding and original owners

The sealed v119 ratio17safe-projectile packets/4spawned is EXPECTED:13 active
spell rows have Proj0 and those messages deliver cast presentation only. Four
Daze packets have Proj1. Magic Missile instead delivers ten server5/3 effects,
visualeffects Type_FD P, whose active ProgFX_Impact selects a progfx Type10 row.
The existing visual adapter diagnosed that general start/stop branch as missing.
Captured packets, physical row classification and old diagnostics establish this
cause; the ratio alone did not demonstrate a dropped ordinary projectile.

StartProgram14096a110 dispatches Type10 to complete14096a9a0..14096afea.
StopProgram14096fa90 has no Type10 action; frame dispatcher140972090 also has
none. The created CNWCProjectile has independent AI lifetime and is not B8.
Native start looks up target render THEN source render, reads Param1model,
Param2spell metadata (initial340), Param3orientation byte (initial0), Param4path
(initial0), Param5duration mode. It constructs ONE projectile, configures spell
sounds/facing1409876a0, overrides facing, loads the Param1 CResRef, queries the
source handconjure WORLD pose twice, falls back to source origin, copies source
orientation, binds scene and starts stage1. Zero point uses target origin plus
native target/prefix setter9873d0; nonzero point leaves constructor INVALID ID.

Duration "log" uses source/target origins and original float log math. Other
strings use projectile-launch/target origins and140762900 speed55; exact
"linear2" doubles the truncated DWORD. Strings are case sensitive C strings.
Time setter9873c0 writes remaining/total, then987770 initializes the selected
path. The safe-projectile receiver's path4 five-projectile expansion does NOT
apply here: five server effects create five, not25, visual projectiles.

680whole original starts execute unchanged in isolated Unicorn memory, with
actual magnitude/log/float branches. CResRef/model/scene/lookup,
allocation/constructor, string/table services and final projectile setters are
explicit synthetic lower boundaries. Exact callbacks, output/fallback positions,
endpoints, flags and times match. Finite profiles are not arbitrary FP/renderer
or whole-subsystem proof. Original GetFeat/attack work remains separate.

## Integration and validation

Resource data is prefetched without creating a projectile/model before native
StartProgram. A prepared model lease keeps assets alive after the originating
visual retires, releases exactly once after the projectile, and rejects replaced
canonical identities and late completion after teardown. One internal client
array/RNG/path/AI owner serves ordinary and procedural projectiles. Canonical
server objects, their IDs/cursors, HP, effects and gameplay RNG remain unchanged.
Creature, placeable and door prefix projections use original loaded-model names;
the actual GPU fixture covers creatures and placeables. Singleplayer passes its
area's existing projectile owner explicitly and uses the same implementation.

137focused projectile/model/reference/visual tests and buildv2 pass. The first
broad check exposed a pure linked-reference fixture without a renderer update
method; renderer reference animation is now optional on such lower owners.
The existing singleplayer linked lifecycle, late loads and ranged tests pass.
Unit cases cover native table/branch order, one-projectile path4 admission,
independent lifetime, canonical nonmutation, model failure and stale teardown.

Installed WebGL replay UIv2 exits0. Ten authentic v119 effect packets create,
render, impact and destroy five missiles each on a creature and placeable,
zero failures, no retained instances,1008peak missile particle vertices. Actual
vpr_magmisl art/textures are loaded from the install in memory. Screenshot
inspected. Bodies/poses/time are explicit synthetic fixture inputs; no new live
acceptance is inferred. UIv1 failed before rendering because its new HTML lacked
the local Three.js import map; v2 corrects that fixture setup.

Native attenuation/loop audio, broader procedural types, client flag28 update
ownership, particle/material/scene limits and hostile/shared gameplay remain
open. Unsupported calls remain diagnosed. Full goal ACTIVE.

## Sealed live player acceptance and next failures

Real v124 closed normally; local-network-procedural-projectile-v124.json has
523wire messages and153232500bytes, SHA256 38ffe52827deb467fde2e9c319a95d8e510eed53b9b926ae5f12d13b36cae1d9.
Two production hotbar/canvas requests sent native6/18; original server returned
two cast start/release pairs and ten player-source5/3 effects. First cast:
five source-tagged projectiles18..22 all loaded, reached stage2 and destroyed;
zero projectile failures and zero durable runtime error records. Protected
dummy damage remains zero by server authority. Original33744/server20964 were
unchanged, both canonical player identities and77/86HP were present. This is
not active shared combat or a hostile victory.

Repeat-cast individual reconstruction is limited by the64-event ring and
renderer stalls: eight player starts across both casts remain sampled, not ten
fully traced lifetimes. Native ten-effect delivery is independently captured.
The conditional live screenshot was inspected; it does not distinctly resolve
every missile. Actual installed GPU particle rendering is proven separately
by the replay fixture. Do not replace these limits with aggregate counts.

The test driver now applies control revisions between samples and can replace
pending actions while preserving earlier failures. v121/v122 missed the canvas
or hit the chat overlay; neither is a successful player-cast test. v123 failed
before connection because the sandboxed Electron GPU helper could not launch.
v124 used normal desktop GPU permissions. An invalid QA creature.talk request
was rejected, retained and corrected to verified conversation.start.

Native guard dialogue recognized completed wizard training and unlocked the
exit. Native area packets then selected m0q1c and returned to m0q1b about9seconds
later. A queued old-door test step failed after this area change. The return
remains unresolved; this is not accepted campaign progression.

Six sampled render calls exceeded1second (about3.6..22.7seconds), with increases
in shader program counts. Driver sample gaps reached45seconds. Startup-only
compileAsync does not cover these new runtime profiles. Next investigate general
shader preparation, then the native doorway return using complete outbound
action capture and installed campaign scripts. No gameplay workaround, local
quest unlock or server patch was added. Full multiplayer goal ACTIVE.

Post-seal checkpoint multiplayer-procedural-projectile-live-20261019-v2.zip
VERIFIED43files/38587296bytes; independent audit verifies45entries,2parent
hashes,11required files,0missing/forbidden/duplicates/new credential candidates.
The audit and this post-seal note are outside the archive. Replacement v124
closed normally; no replacement session is left running. Original33744 and
server20964 remain running. Full goal ACTIVE.

Read-only authored-door follow-up: m0q1b M0Q1B_M0Q1C and m0q1c
M0Q1C_M0Q1B link reciprocally and have empty OnOpen/OnClick fields. m0q1c
OnEnter is empty; installed OnExit source only clears the departing PC plot
flag. These fields do not explain the return. The heartbeat resource script1
has no installed NSS source in the active resolver. Capture outbound movement,
door, dialogue and area-ready requests in the next test; current quickbar-only
outbound filter excludes them, so no causal attribution is justified yet.
