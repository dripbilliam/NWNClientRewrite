# Native moving projectile audio — 2026-10-19

NWN:EE89.8193.37-17, nwmain SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Original installed files and processes remain unmodified.

Existing original AIUpdate140983860 owns flight-loop timing. Position update
983bb8 uses native XYZ+height1.5. Creation983d27 calls CExoSoundSource
constructor1d95b0;983d42/983d50/983d5e set priority12,3D1,loop1, then
983d81 moves the new source before Play. At impact it stops/deletes the loop,
clears the pointer and emits its separately owned impact one-shot. The
existing original-code oracle has1356 whole AIUpdate executions with timer,
path, stage, camera, audio API and deletion captured as explicit lower services.
Focused tests still match its exact ordering and surviving fields. This is
not an original hardware audio or live-server test.

The renderer adapter now uses shared NativeEffectSound/BufferAudioSource
through an optional sound factory. NetworkScene's existing active-scene
factory supplies it; active spells.2DA ProjSound controls the resource, with no
spell/module/server-specific output branch. Existing native path/AI owners
are unchanged. Canonical uint32 IDs, effect/property IDs, native RNG, server
actions, scripts, hit/damage and spell resolution are untouched. The source
has OBJECT_INVALID as diagnostic object context; no new canonical object or
invented server-visible projectile ID is allocated.

Explicit output disposal also releases a flight loop on area unload, including
pending WAV decoding. The native projectile destructor9835c0 does not itself
show sound-pointer cleanup; no claim is made that this additional browser
resource teardown is a literal call in that destructor. Ordinary impact
stop/delete sequencing remains in983860 and is not replaced by local timers.
Shared source disposal is idempotent, including when GameAudio already closed.
Late resource completion cannot restart stopped/destroyed output.

Bounded projectile presentation events record loop creation, play request,
stop and destruction (including source snapshot). Per-frame moves do not
emit log rows. Counts distinguish playback requests from actual output;
the source snapshot's played field records browser BufferSource starts. Missing
factory keeps the existing unimplemented diagnostic. Missing WAV is recorded
once and does not change projectile travel, impacts or authoritative gameplay.

27focused and99projectile/audio/visual regressions pass. New integration cases
exercise the real shared source class with native AI/path ownership, moving
pose, independent5-projectile sources, impact disposal, area teardown before
decode and unavailable WAV. Existing singleplayer projectile tests pass;
its legacy audio-coordinate path keeps the prior diagnosed missing factory.
Native mixer limits, synchronized pause, range-resume sample phase and exact
hardware priority behavior remain incomplete, as documented for shared audio.

Muted Chromium PCM fixture selects an installed mono homing projectile sound
from active spells data (row0/spr_ectoacid01 in this install), and runs the
production network projectile adapter, native AI/physics and GameAudio. Real
PCM peak0.0712473169, priority12/3D/loop, actual movement and impact cleanup
pass without changing canonical world/allocator. Model, pose and one-shot
services are isolated; this fixture does not validate geometry, a live cast,
or original hardware equivalence. The JSON and screenshot preserve scope.
Buildv1 index-BGSk2Xsc.js passes with the existing bundle-size warning.

Live rollout is pending the verified source checkpoint. Current147/PID18816,
original33744 and vanilla server20964 remain running. Full multiplayer goal
ACTIVE; shared original-origin combat/casting, remaining voice/combat sound,
initial attack approach and broader campaign acceptance are incomplete.

## Live vanilla-server acceptance

Source v1 checkpoint25files/1030549bytes was verified before reconnect. The
independent27entry/12parent audit found no missing/forbidden/duplicate/new
credential candidates. Original33744 and server20964 stayed running unchanged.
SEALED147:304samples/157wire, normal save/close/no capture failures.

SEALED148/PID1824:343samples/81wire, normal save/disconnect, zero runtime or
capture failures. Existing prepared quickbar Fireball58 plus a physical
exposed-floor click produced native start/release feedback, server prepared
uses2->1 and one real safe-projectile header. Two earlier physical target
points were hidden by room geometry and sent no request; those attempts are
retained. After a normal camera orbit, the actual picked native point was
21.408894,85.112266,0. Header endpoint matches it plus the native0.3height.
Caster stays30,85; local77HP and original86HP remain unchanged. No enemy,
original player, server rule or game file was modified. This is a validation
scenario, not a spell-specific audio implementation.

The client loaded vpr_fireball, moved it, impacted and destroyed it without
failures. Exactly one spr_fireball loop/source starts: priority12/loop/3D,
volume127/raw44100Hz/duration2739ms. A live pre-impact position and the stop
snapshot prove movement without restart; endpoint sound Z1.8 is target0.3+1.5.
Stop observes browser source playing/played1; destruction observes idle, and
no flight source remains. The separate native projectile impact one-shot and
area/object explosion cues also decode/play. Full-wire executable replay
verify-network-projectile-audio.mjs checks the source identity, spell/rules
resource, actual UI target/header, preparation spending, movement, cleanup
and unchanged health. QA snapshot components are separately read, not atomic.

LIVE passive149/PID47948 runs final index-BGSk2Xsc.js at m0q1d/144tiles,[30,85],
with both canonical player portraits, no failed scene objects/runtime errors,
and no scheduled gameplay inputs. Frozen current149 JSON and ready screenshot
are explicit; its active full capture is excluded. Original client is in
another area and passive: no new original-origin shared active combat/casting
acceptance is claimed. Native mixer/voice limits, synchronized pause and loop
phase, remaining combat/voice/renderer owners and campaign parity remain open.
Full multiplayer goal ACTIVE; final live-inclusive checkpoint follows.
