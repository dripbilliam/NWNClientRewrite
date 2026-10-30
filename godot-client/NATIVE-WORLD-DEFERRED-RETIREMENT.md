# Native area retirement with live data workers

Status: implemented with scoped native-worker, default-entry and actual owned
Prelude transition evidence. Broader ordered goal remains incomplete.

## Original teardown boundary

Immutable original NWN:EE89.8193.37-17 x64 nwmain.exe SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No original executable/assets/Ghidra database were modified.

Fresh complete function1407e7770..1407e7cf1 is called by the area receiver before
new area loading. It mutes effects (1407e7790->1401d9c20), clears grass
(1407e7795->14006c8b0), tears down scene-owned fields and collections, deletes
selected canonical IDs (1407e7933->140296360 and1407e7ba3->1402963d0), removes
linked-list heads (1407e7aa7->1401692a0), and detaches other retained object state.
Collection meanings and indirect destructor bodies are not all reconstructed.

Selected derived complete pseudocode/assembly and relation limits are retained
in `backups/animations/rea-world-area-retirement-v1.json`, excluding duplicated
raw results/high-pcode. `scripts/inspect-native-world-retirement-boundaries.py`
checks five exact call instructions with an executable hash gate. Neither these
checks nor this function establish an original asynchronous worker-cancel
algorithm. A negative symbol-name search does not prove such an owner absent.

## Godot adaptation

The old native path synchronously joined every asset job during `world.close()`
inside receipt of a new area or session reset. A slow read/parser could block the
main/network frame before the new world even started. Immediate freeing would
instead be unsafe: worker callbacks still use their service/mutex owner.

`world_retirement.gd` now retains old worlds without reparenting them. Reparenting
would invoke `_exit_tree` and the blocking close. Retirement immediately hides
the old world, disables its processing and collision layers/masks, disconnects
world publication/removal callbacks, and cancels pending asset jobs by advancing
their epochs. Running private-data workers keep valid owners. Snapshot/movement
receipt and streaming plans refuse the retired scope.

Each frame the retirement owner checks actual existing worker task handles,
including area-definition work. Once all complete, normal close joins them,
clears the results and releases their scene/resource owners. No old callback can
remove an ID from the current registry: the previous callbacks capture current
root fields, so they must be disconnected before deferred close. Old physical
pick bodies cannot intercept the next area's pointer rays.

Two retired worlds may be retained. Overflow safely drains the oldest; explicit
shutdown joins all remaining jobs. This bound can cause a wait after sufficiently
rapid transitions, while avoiding unlimited retained scenes. The bound and this
deferred Godot ownership policy are our design, not a claimed original algorithm.
Current-world shutdown and session catalog mounting still use synchronous joins;
those other boundaries were not silently relabeled nonblocking.

The default `native_live_world.gd` area-generation switch and the normal
`native_session_world.gd` session reset use this retirement owner. The original
server continues to own area changes. No protocol/rendering work moved to JS.

## Verification

- `native-world-retirement-v2`:72 native checks with actual WorkerThreadPool jobs
  and native file-backed authored MDL/2DA readers. A semaphore holds one actual
  read at a declared provider boundary. Six cycles prove retirement returns with
  that worker still live, subsequent frames continue, the next world prepares and
  publishes its mesh/player, and old owners/services release only after completion.
  Canceled completion and stale registry callback counts remain0. Also exercises
  two blocked worlds, bounded overflow, explicit shutdown and zero survivors.
  Source uses stub player/terrain admission and a controlled read boundary; it
  is not a complete network transition replay or a timing/FPS benchmark.
- `native-visual-failure-retirement-regression-v1`:28 actual-worker visual failure
  admission and required-failure checks remain green.
- `native-template-retirement-regression-v1`:16 GPU shared immutable templates /
  private instances / four streams /48 objects and eviction checks remain green.
- `native-world-retirement-prelude-v1`:existing authoritative native Prelude
  gameplay route under CDB. Click walk1.500033 m, keyboard movement2.860857 m,
  inventory server-owned equipment round trip, examine/two conversations, actual
  open/transition door, then inventory reopen in generation2. First area20
  entities/nine tiles; second92 entities/100 tiles. Object bindings complete,
  finish acknowledged, no retired worlds/workers and clean exit. The actual
  transition had no old worker pending; the controlled-worker test covers that
  separate case. Screenshot inspected: original room/character/props and chat
  present. Its single displayed156 FPS sample is not performance acceptance.
- `native-session-world-retirement-v1`:actual normal native multiplayer launcher
  on owned localhost. Player ready1449.538 ms with1/19 entities and two background
  batches; native/server movement observed while18/20 entities and two batches
  remained. Final complete20 entities/nine tiles, finish acknowledged, workers0.

Accepted runs use normal-heap CDB with four traps, unchanged runtime sources and
no trapped native or engine/lifetime error. Initial retirement fixture v1 failed
to parse because it treated Semaphore.try_wait's bool as an Error and inferred
Variant weak references; retained failure, not a pass. Final v2 is accepted.
Editor1776 is preserved. No public connections occurred.

Effects are still incomplete: Prelude's second area reports236 emitters,114
diagnosed failures and18 with simulation frames. No complete-scene or clean
cold/warm/FPS claim follows. Repeated real return transitions/reconnects,
definition-worker cancellation coverage, native priority/culling, lower resource
cancellation, full moving-world capture replay and historical native faults
remain open. Full JS migration and the final reference wiki follow the first
phase in BINARY-WORLD-STREAMING-GOAL.md.
