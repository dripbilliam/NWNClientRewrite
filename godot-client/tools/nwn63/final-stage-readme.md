# NWN-63 final production pair

The coordinator freezes the candidate source after the collision owner finishes. Run the read-only `draft` command below into a fresh plan, review its source hashes and collision control file, then set `complete` to true. `final-stage-plan.example.json` shows the schema. The control uses the pinned prepatch `drive_collision_indexed.gd` and reverses exactly the two `keyboard_frame_admission` default-true expressions. The current `native_keyboard.gd` idle guard remains byte-identical in both legs. Any extra source difference fails staging.

From `godot-client`, create the plan after freeze and run the read-only gate:

```powershell
node tools/nwn63/final-stage-pair.cjs draft --label=keyboard-collision-b | Set-Content -Encoding utf8 .cache/nwn63/final-plan-b.json
# Review the plan, then change complete to true.
node tools/nwn63/final-stage-pair.cjs verify-only --manifest=.cache/nwn63/final-plan-b.json
```

After every source writer has stopped and the coordinator owns the frozen-source gate, stage immutable selections without starting a client:

```powershell
$env:NWN63_FINAL_FROZEN='coordinator'
node tools/nwn63/final-stage-pair.cjs stage --manifest=.cache/nwn63/final-plan-b.json
node tools/nwn63/final-stage-pair.cjs verify-only --receipt=.cache/nwn63/final-keyboard-collision-b/pair.json
node tools/nwn63/final-stage-abba.cjs verify-only --receipt=.cache/nwn63/final-keyboard-collision-b/pair.json --tag=a
```

The verify-only commands do not spawn clients. They require all source selection pins, the accepted Core E/native DLL hashes, identical normal render/layout seeds (gamma 1.2, FOV 45, particles and compact scenery enabled), the normal replay driver, the original generation-2 `recording.json` and 77 MB `timeline.jsonl`, and four unused report labels. They validate that the two selections differ only in the coordinator keyboard defaults and the exact collision control file. Staging writes only under fresh `.cache` labels; it does not modify production source or game assets.

The coordinator runs the recorded graphical ABBA only after an exclusive FPS lease and other agents are idle:

```powershell
$env:NWN63_FPS_LEASE='root-exclusive'
$env:NWN63_FINAL_RUN='coordinator'
node tools/nwn63/final-stage-abba.cjs run --receipt=.cache/nwn63/final-keyboard-collision-b/pair.json --tag=a
```

The order is control A, candidate A, candidate B, control B. Each leg rechecks the immutable selections and recording, uses a fresh report label, and requires 360/360 movement, observed camera and preferences, area 2147618622 with 1,918 entities, 1,784/1,784 base scenery resolved with none pending/failed, complete object visuals, empty world/object failures, and a steady performance window of at least 10 seconds. The candidate must report a ready static group index with entries, build steps, zero unsafe groups and numeric `last_query` visit/test counts; the control must lack that index. All four legs must retain the same 3440 × 1369 viewport and FOV 45, gamma 1.2, enabled particles, disabled particle collision, compact scenery, disabled frame cap and VSync, with identical begin/end settings. The ordinary recorded replay does not inject OS keyboard input; its numeric keyboard counters may remain zero. The earlier E burst ABBA is separate keyboard evidence. The runner preserves partial results if any leg fails. Normal live Arelith keyboard, click movement, authority and visual acceptance are still separate.

