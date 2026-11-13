# NWN-63 frozen candidate: live Arelith handoff

This launcher consumes the final `pair.json` and its **candidate** production selection. It copies exactly that pinned source, accepted Core E engine and native DLL into a fresh live stage. Its render/layout working copies come from the same immutable seeds as the final recorded ABBA. It never calls the older `native-live-review/prepare.cjs`, which has source overrides from earlier tickets. A stage or verify command does not open a client.

After the collision source is frozen, the final pair is staged and its offline ABBA passes, the coordinator prepares and verifies a fresh live stage:

```powershell
node tools/nwn63/live-launch-stage.cjs prepare --receipt=.cache/nwn63/final-keyboard-collision-b/pair.json --label=arelith-a
node tools/nwn63/live-launch-stage.cjs verify-only --config=.cache/nwn63/live-arelith-a/config.json
```

With other FPS/CPU work quiescent, the coordinator starts the normal client. The launcher recomputes the current secondary monitor index, starts Electron hidden without activating it, and passes `--native-screen` to the game. It refuses to start if no secondary monitor exists. The user chooses Arelith and logs in; the launcher does not automate either step.

```powershell
$env:NWN63_LIVE_RUN='coordinator'
$env:NWN63_FPS_LEASE='root-exclusive'
powershell -NoProfile -File tools/nwn63/live-launch-run.ps1 -Config .cache/nwn63/live-arelith-a/config.json
```

Use one familiar Arelith corridor or open area: observe 10–20 seconds idle, hold a movement key long enough for repeated turns, release to a full stop, repeat with a different direction and camera turn, then click a reachable destination and let it finish. Record the location, route, visible FPS range, camera behavior, movement corrections, stalls and any visual failures. The native report's keyboard `drive`, `stop`, `previews` and `admission_events` must show actual held-key activity; the recorded offline ABBA may legitimately have zero OS keyboard counts. Check click movement and server-authoritative position separately. Compare this run to the same route on the frozen control if live A/B is needed; do not compare it to an old source snapshot.

Quit through the game menu and wait for the launcher to exit. Retain `.cache/nwn63/live-arelith-a/{config.json,manifest.json,launch.json,host-start.json,native-start.json,working-settings-proof.json,launcher.stdout.log,launcher.stderr.log}` plus `project/reports/nwn63-live-arelith-a.json`, `.native.json` and `.engine.log` when produced. Hash each saved file; record native PID and creation FILETIME from `native-start.json`/`launch.json`, engine/DLL hashes, current monitor topology, raw native keyboard counters, settings/FOV/viewport, area/entity counts and frame interval window. Stop and retain partial evidence on any startup/setting mismatch.

The accepted Core E binary is uninstrumented, so this live stage does **not** connect to Tracy. If a CPU zone trace is needed, create a separately identified private Tracy diagnostic session from the same frozen source and pass its native acceptance gate. The diagnostic launcher is `tools/native-tracy/live/launch.ps1 -Config <diagnostic-config> -NativeAcceptance <exact-stage-acceptance> -Launch`; its default mode is readiness only. Connect Tracy 0.13 to `127.0.0.1`, perform the same route, stop capture after movement, save a fresh `.tracy`, then exit normally. Save the trace SHA256/size, session config and manifest, launch/native PID and creation time, actual instrumented engine/DLL hashes, stdout/engine logs and `tools/native-tracy/trace-verify.cjs` result. Treat Tracy CPU attribution as diagnostic; its engine/DLL and FPS are distinct from the accepted Core E run.

