# Doors, transition selection, held movement and area-loading stalls

2026-10-27. Fixes for the user's three reported playability bugs. Native source
and headless component acceptance; actual-server/visual/loading-time acceptance
is still required. No automated public connection, server launch or graphical
benchmark was performed. Particle optimization remains paused.

## Behavior changes

Doors previously used object_stream's static PackedScene route. Received open
state could change interaction/DWK behavior while the original door Parts stayed
visually closed. door_instance.gd now uses the native actor/rig loader for doors
selected by the active genericdoors/doortypes tables. Initial state selects the
original closed/opened pose. Authoritative state updates play opening1/2 or
closing1/2 and settle into the original rest clip. Repeated updates preserve the
current phase. No optimistic state change or server rule is synthesized.

object_animation.gd ports original door9b0790/placeable9b20a0 names. Its entire
1281-case retained original corpus passes, target nwmain SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Destroyed-model flag/animation-replacement coverage and broader door variants
remain separate acceptance; the original-resource test covers normal side1/2
open/close/rest clips, not every door/death override or server script.

Received transition triggers were eligible in policy but absent from model
streaming, so they never had a selection surface. transition_targets.gd now
projects the received world-space polygon into the existing native physics,
hover/Tab highlighting and label registry. Ordinary scenery stays outside that
registry. Trap/foreign/removed/invalid polygons remain excluded. A click requests
normal movement to a point inside the actual concave polygon. The original
server decides activation and travel; no client transition is fabricated.

The polygon follows original client7b1670/86f940 world-space vertices and Z+0.05,
as retained in ../src/network_trigger.js and its original evidence. Godot native
triangulation replaces Three's triangulator. A full snapshot, delta removal,
connection reset and world retirement all remove old selection ownership.

For held W, combat_animation.base_frame started locomotion looping, then its
unchanged-animation branch used the action-category bit as a loop flag. Run and
walk category0 became one-shots on the next observation. The base-loop decision
now keeps all existing path locomotion codes repeating, preserving explicit
loop-map overrides and speed/phase. The action-category mask itself is unchanged.

The completed user's log also exposed a deferred pointer callback after UI reset
(blocks_pointer on Nil). Session reset/area replacement now disables the old
input owner immediately, and the shared pointer guard validates current owners.
This corrects that demonstrated callback error; it does not explain every older
shutdown failure or the user's missing final native result.

## Loading evidence and fixes

The baseline is the completed native-user-1793081747829 session. Derived evidence
with a digest of its performance log is in
reports/native-loading-user-review-v1.json. No new public connection was made.

- A35.369s frame spent35.332s in main-thread protocol/state application.
- Another frame spent12.820s in retired-area cleanup. Other snapshots stalled
  inside root statistics. Low recorded renderer times in these frames do not
  establish steady-state GPU/FPS performance.
- The final observed area reports57.666s to playable, while tile definition took
  43.233ms. Its42 model workers total12.856s of elapsed worker durations, and
  terrain publication totals1.546s. Sums of worker durations are not wall time.
- The memory tier reports5,531 evictions. A data-release worker reports91.439s
  elapsed. This is evidence of heavy data churn/cleanup and possible contention,
  not a measurement of91s of exclusive CPU time.

Concrete source defects fixed:

1. preparation_store evicted recursively expanded model graphs while holding a
   mutex also used by main-thread asset requests and diagnostics. It now detaches
   graphs under the lock and destroys them afterward. Diagnostic snapshots use
   try_lock and explicitly mark a stale metadata snapshot when a worker is busy.
2. prepared_cache publish re-read/deserialized a full existing model under its
   global publication mutex, then immediately discarded the duplicate graph.
   Identity validation and destruction now run outside that lock. Bounded small
   publication proofs avoid another Variant decode for known immutable entries;
   payload checksums are still streamed and verified, including same-length
   corruption. The final short publication step rechecks the file fingerprint.
   Payload decoder/source identity, atomic repair and temporary cleanup remain.
3. world_retirement closed all old scene owners synchronously in one callback.
   Real completed worker handles still gate release. Physical owner destruction
   now proceeds in bounded steps (four owners/2ms target per step). Detached
   decoded results/terrain data go to the existing data-retirement workers.
   Audio stops at retirement start; GPU/scene owners stay on the main thread.
   Retention overflow and explicit shutdown keep their existing safe forced drain.

These changes address demonstrated blocking mechanisms. They do not prove that
every35s apply stall came from the same lock, or establish a post-fix load time.
Large individual model publication/selection, data-copy/destruction costs and
remaining worker contention can still cause hitches. New profile spans separate
transition_old_snapshot, transition_retire_begin, transition_world_open,
snapshot_world_and_ui_apply, snapshot_combat_effects, snapshot_scene_metadata
and snapshot_preparation_cache for the next actual transition check.

## Verification

All accepted runs use test-native-kernel-debugger.ps1, headless, source-pinned,
four native exception traps and terminal exit0. No accepted engine/lifetime
error or native exception. Actual original resources are read externally.

| Report prefix in reports/ | Checks | Scope |
| --- | ---: | --- |
| native-bugs-final-core-v1 |1314|1281 original selectors, actual AnimationPlayer over15 gait periods per code, phase/speed, held metadata lock, actual transition physics/mark/removal |
| native-bugs-final-door-v1 |15|Installed original T_DOOR01/table/worker, physical Part movement, both open/close sides, rest phases and unchanged authority |
| native-bugs-final-disk-cache-v1 |16|Persistent integrity/decoder identity, same-length corruption with/without prior failed read,8 real concurrent repairs/publications and no temp leftovers |
| native-bugs-final-retirement-v1 |72|Real blocked workers, next-world continuity, cancellation,6 replacements and bounded retention/forced drain |
| native-bugs-final-interactions-v1 |32|Scenery exclusion, active usability, original invisible portal hit geometry and native physics selection |
| native-bugs-final-casting-v1 |28|Original native casting/physical effects regression; existing missing-fx_ref/point-to-point warnings remain open |
| native-bugs-final-disconnect-v1 |14|Actual connection reset, queued sound cleanup and safe post-reset pointer guard |
| native-bugs-final-loading-v1 |18|Actual loading milestone/input/active-art behavior |
| native-loading-contention-v2 |11|Another resource completes publication while one real worker's validation is held; actual world releases in bounded steps and eventually frees |

Total1520 headless assertions. Earlier runs retained: regression-v1 failed a
fixture Vector3 type annotation; loading-contention-v1 failed a fixture WeakRef
annotation. The first casting command used a nonexistent test filename; the
correct existing native_cast_visual_world_test passes. None is counted as a
passed run. Reports before the final new test pin the same production sources;
the acceptance audit verifies every retained pin against the final worktree.

Real door requests/server replies, trigger arrival/zone-edge travel, visual
pixel comparison, full custom content and cold/warm loading improvement still
need the next local/manual test. No new FPS or elapsed-load improvement is
claimed from these headless checks. Full base-gameplay goal remains incomplete.

## Authorized localhost follow-up

native-playability-prelude-live-v4 passes on the unchanged owned Prelude server
127.0.0.1:5121: four real door travels, server-observed movement, native original
inventory icons/equipment roundtrip, dialogues, stale reply recovery and clean
CDB-guarded shutdown. SourceUnchanged=true; no native exception or engine error.
The editor remains open, so this is functional/loading evidence, not clean FPS
acceptance. Existing wind/particle warnings remain separate open limitations.

The prepared model cache starts in a new empty external temporary directory,
then is reused for the same-process visits and removed after the client exits.
The usual user cache is preserved. Initial room/player playable14.226s;
first training-area visit1.060s; three revisits0.628/0.621/0.619s. These are native
world-open-to-control milestones, not full login wall times or direct Arelith
comparisons. All desired objects finish rendering for each travelled area.

Held W yields426 gait samples,420 advancing samples, a phase wrap and zero
nonlooping samples across3s. The live travel doors were already open, so that
run does not establish a new server-open request/visible opening animation;
the preceding original-resource component test remains the opening evidence.
Explicit live close/reopen still needs validation. The first campaign door
attempt correctly received the server's story-barred response; the fixture now
selects authored linked exits from the unchanged campaign GIT, without forcing
an unlock. Earlier failed reports are retained, not counted as passes.

The first live attempts also exposed a stale-dialogue reply race. Both protocol
hosts now reproject the current received dialogue (or close its stale projection)
when session.replyDialog rejects an obsolete choice. No rejected choice is sent,
and unrelated errors still propagate. Four dedicated Node cases pass.

Linked trigger polygons are absent from Prelude. Reviewing the original request
path established that trigger travel must retain the selected trigger ID; a
bare ground walk is insufficient. Native clicks now send trigger.transition with
the native-computed approach position through the protocol adapter. Its exact
movement packet is checked while imports of legacy geometry/Three are forbidden.
The existing JS frontend fallback remains separate. Actual linked-trigger travel
on the owned dense fixture and an explicit live door close/open are still pending.

User steering: a slower very-first load is acceptable. The user will manually
test Arelith next with profiling; automated public connections remain forbidden.
