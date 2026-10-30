# Player-centered native streaming and hitch investigation

2026-10-27. Scoped implementation and native regression coverage; complete
gameplay, streaming performance and mixed-client acceptance remain incomplete.
The user manually connected to Arelith; automated connections in this work used
only the owned localhost Prelude server. Original binaries/assets are unchanged.

## Original binary order

Read-only target: NWN:EE89.8193.37-17 x64 nwmain.exe, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

* ClientArea receiver14076d910 calls LoadArea1407dba70 at14076e315.
  Its loading-screen setup precedes that call; prior complete assembly and
  findings remain in NATIVE-LOADING-SCREEN.md / NATIVE-WORLD-JOIN-METHODS.md.
* LoadArea iterates Y outside X, index=Y*width+X. Exact sites:
  1407dcf30 initializes X,1407dcf50..57 computes the index,
  1407dd351 increments X,1407dd368 loops X,1407dd36e increments Y,
  1407dd373..384 loops Y. This grid control uses no player-distance input.
* UpdateScreen1400451c0 is called at1407dcfeb with timer thresholds50000/15000us;
  connection check1402376a0 occurs at1407dd03b inside the loop.
* Tile setup140850110 is called at1407dd0c2;1407dd119 calls14084ef10.
  Fresh complete REA dossier covers14084ef10..14084f1dc. It resolves the
  tile model and calls scene virtual+30; Scene vtable140d8dd30 entry140d8dd60
  contains1400d41a0, exported Scene::SpawnTile.
* Fresh SpawnTile dossier shows FindModel, private instance/static part handling,
  ExpandReferenceParts, CollapsePartTree, ProcessStaticParts, conditional
  CombineParts, and SceneBSPAddTileData. Static tile preprocessing/collapse is a
  separate optimization opportunity; this change does not port all those bodies.
* FindModel's shared parsed-model hit and synchronous miss route are independently
  covered by the existing80-case original-code oracle. Controlled held-model
  priority2 versus remote4 is covered by the earlier220-case equipment oracle.
  Neither proves a universal nearest-first original object scheduler.

Fresh evidence: backups/animations/rea-player-stream-tile-load-v1.json and
rea-player-stream-spawn-tile-v1.json. Factory/vtable reads used REA evidence
ev_319f3f175d22822885fed053d62dfe24a8298f880d1fabca0fa06cdc5797d972 /
ev_ad6bb78374a7405d846e557ce2240aed0a15d8758be3b2fe6d95fa2eea188fdd.
scripts/inspect-native-player-stream-order.py independently hash-checks15 exact
instructions and executes the original grid-control slices for6 dimensions,
893 tile indices. It explicitly skips I/O/model/UI/network loop-body work;
it is not whole-loader or scheduler emulation. Receipt:
backups/animations/native-player-stream-order-v1.json.

## Implemented presentation policy

The user explicitly requested player-centered priority even though the original
terrain loop uses grid order. Server authority, original resource/rule precedence,
tile indices, geometry and the eventual complete object set stay unchanged.

* Raw server entry position seeds terrain and walkmesh preparation before the
  player model exists. The rendered controlled character then supplies the origin.
  Pending work reprioritizes after at least2m of movement, rather than sorting
  the entire registry every settled frame.
* Unique tile/scenery models rank by their nearest placement. Each ready tile
  and scenery placement publishes by distance across model groups. Completion
  order therefore cannot force all far placements of one model ahead of nearby
  placements of another. Actual remaining-placement counts retain CPU bundles
  correctly when the last file-order tile publishes first.
* Actor plans and their complete model dependencies rank by distance; the
  controlled appearance remains first. Background admission uses a shared
  nearest64-object wave across actors/items/statics, within the existing owner
  and category bounds. Distant actors no longer enter solely to fill a category.
* Ready visible-world admission is sorted across all independently completed
  owners. Referenced models rank by their nearest live physical owner too.
* Unstarted native asset requests can be reprioritized; each stream queues only
  a small multiple of its worker count. Running jobs are not aborted. Ready work
  does not wait for a slow or unavailable closer dependency. This is best-effort
  nearest-ready streaming, not a strict distance barrier or distance culling.
* Full required terrain/surface readiness still gates area-ready. Waiting for the
  controlled actor before that acknowledgment can deadlock original servers.
  Background entities continue after the player is ready; models remain complete
  private hierarchies, never half-equipped actors.

## Captured hitches and disposal change

Manual run native-user-loading-1793087350391 contains a5548.867ms frame with
5547.053ms in callback_retirement, render CPU0.360ms / GPU0.453ms. Other retirement
frames include3530.239ms and1329.801ms. That stall is old-world cleanup, not proof
that distant terrain drawing or network latency consumed five seconds.

After the first priority build, manual native-user-player-stream-1793089188831
contains a128.843ms frame,96.618ms in snapshot_world_and_ui_apply, GPU2.716ms,
with the world count changing920→919. Later entity departures coincide with
83.481/42.382ms world/UI apply peaks. The combined span does not isolate the
whole cost to removal; that attribution remains a hypothesis. With particles
enabled, separate frames show74.227ms in callback_particles. Turning them off
does not eliminate the receive/streaming hitches.

Completed referenced-model caches now detach to the persistent data-disposal
owner during retirement. Actor removal retains immutable decoded rig sources
through main-thread physical teardown, then drops those references on the data
worker. Live Parts, Nodes, materials, animation owners and GPU resources remain
on the main thread. Shared model data is not cleared in place. This addresses
one synchronous destruction path; it is not yet a measured public-session fix.

New spans separate snapshot_native_delta, snapshot_ui_apply, entity_removal,
retirement_detach_data, retirement_entity_release, retirement_tile_release,
retirement_incremental_step, retirement_final_close and close subowners.
Rolling-window worst-frame timestamps are report times, not exact frame times;
child spans overlap and must not be summed. Renderer timings are asynchronous.

## Validation and limits

Final current-source headless normal-heap CDB receipts (4 exception traps,
source hashes unchanged, no trapped exception or engine/lifetime error):

| reports/ receipt | Checks | Scope |
|---|---:|---|
| native-player-stream-final-order-v1 |20|Actual native authored tile/scenery publication, reversed completion, interleaved shared models, moved origin, complete actor dependencies, reference dispatch, cross-owner admission.|
| native-player-stream-final-planner-v1 |46|Existing controlled priority/reference readiness and eventual exactly-once bounded planning.|
| native-player-stream-final-adoption-v1 |6|Existing publication quota/completed-owner retention and cleanup.|
| native-player-stream-final-retirement-v1 |72|Real worker cancellation/retained ownership, safe overflow and shutdown.|
| native-entity-data-retirement-v1 |10|Actual native actors sharing immutable rig data; parked disposal worker, continuing frames, scene retirement, final drain.|

154 assertions; production native_session_world.gd check-only parse also passes.
Initial ordering fixture v1 lacked the mock owner's new origin setter; corrected
fixture v2/v3 and final tests pass. Retain the failed receipt.

Local live attempt native-player-stream-prelude-v1 timed out during login.
After restarting only the empty owned Prelude server, v2 entered/rendered the
world without native exceptions or engine errors, but failed the existing strafe
assertion before its door/area-transition route. It is not a passing end-to-end
or transition benchmark. Neither local attempt made a public connection.

The user-authorized restart now opens native-user-stream-hitch-1793089940680 at
server selection with profiling, after verifying the previous replacement exited.
The user chooses/connects Arelith manually. Previous manual run's source changed
after launch while preparing the disposal patch; do not claim final-build or
unchanged-source acceptance from that session. Live before/after streaming hitch
and original static-part/BSP parity remain open. Audit:
reports/native-player-centered-streaming-audit-v2.json.
