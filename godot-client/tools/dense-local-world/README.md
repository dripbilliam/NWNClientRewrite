# Dense local NWSync benchmark

Build and run from the workspace root in PowerShell 7. `Prepare` assembles DenseSync under a fresh `.cache` directory and packs its resources into a version 3 NWSync repository with Zstandard blobs. The original server mounts a private module and HAK. The manifest contains the required HAK and separate generated terrain bitmaps for the original tileset and model.

```powershell
$fixture = Join-Path $PWD '.cache/dense-sync-dense'
& .\godot-client\tools\dense-local-world\fixture.ps1 -Action Prepare -FixtureRoot $fixture
```

Each of the two default dense areas has 100 tiles, 96 creatures, 320 placeables, 48 doors, and one trigger. The added placeables include static and animated models, and the added doors exercise both open and closed states. The dense repository contains ten generated 512 × 512 terrain bitmaps and the HAK. A fresh fixture built with `-DensityMultiplier 2` doubles the added population while keeping the terrain dimensions fixed. Use `-Scale smoke` for a shorter join test with six creatures, twelve placeables, and two 64 × 64 generated bitmaps.

Build the heavier stress fixture in a separate directory to keep the existing benchmark cases comparable.

```powershell
$fixture = Join-Path $PWD '.cache/dense-sync-stress-4x'
& .\godot-client\tools\dense-local-world\fixture.ps1 -Action Prepare -FixtureRoot $fixture -DensityMultiplier 4 -UdpPort 5128 -HttpPort 5138
```

Each 4× area has 1,472 authored objects across 240 creatures, 1,040 placeables, and 192 doors. The added scenery covers 33 rigid models, with fixtures split between static and replicated placements. The 192 effect and mechanism placements cover 16 appearances, including water, flame, flags, colored lights, and mechanical levers. The repository adds four generated prop surface textures and four particle atlases. Use `-DensityMultiplier 3` for the same mix with fewer copies. For the first headless pass, allow extra time with `-TimeoutSeconds 600`.

On the expanded fixture the server cycles 24 levers per area. The first movement from spawn starts a sequence of door openings and closings on 12 nearby doors, using normal server actions. Client receipts record the door transitions, lever playback, and use of the generated prop textures at entry and after the route.

The original server uses UDP 5127 and the repository uses TCP 5137 by default. Set both ports at preparation time if needed. For server-vault runs, pass `-SeedVault` with an owned fixture vault containing one server character that belongs to the isolated client settings seed.

```powershell
& .\godot-client\tools\dense-local-world\fixture.ps1 -Action Run -FixtureRoot $fixture -SettingsSource $settingsSeed
```

Use an isolated enrolled settings seed under `.cache`. The local-vault route uses the installed pregenerated fighter. `Run` starts and stops its own server and loopback HTTP listener. Each pair writes a fresh directory under `<fixture>/runs` with a client profile, engine logs, `server-start.json`, `http/requests.jsonl`, and `client/summary-pair.json`.

For a successful pair, the cold receipt should show the advertised manifest and every unique blob downloaded over HTTP. The warm receipt should show zero blob downloads when reusing that private cache. The client receipts record the generated resource hashes and selected catalog sources alongside world entry and movement checks. HTTP readiness and packaging alone establish that the repository can serve the fixture. The cold and warm client receipts establish that the game used the synced assets.

The default run validates loading and gameplay headlessly. Use `-Mode frame` for timed rendering on the secondary monitor and `-Mode profile` for detailed callback timings. `-TimeoutSeconds` sets the deadline per leg and defaults to 180 seconds. `-IdleSeconds` sets the idle capture window and defaults to six seconds. Match the fixture, route, window settings, idle duration, and cache state across comparisons. `-Variant gpu-skin` selects the existing GPU skinning path for comparison with `reference`. `-RenderThread` selects `safe` or `separate`. Pause concurrent work during the measured runs.

Use `-Variant cpu-compiled` on a dense fixture to measure the compiled CPU skinning option with the workspace kernel. The receipt checks for successful compiled calls and reports any input rejections.

Add `-CpuSkinPicking` to try on-demand posed picking with CPU deformation. Use `-PointerProbe` on both runs to compare the same picking workload and record how many committed poses require a refit. The interactive launcher accepts `-CpuSkinPicking` as well.

Add `-JoinDiagnostics` in a validation run to record requested, asset-ready, built, and published instances by type, with publication budget denials. The collector stops when the scene settles.

Use a second run with `-JoinDiagnostics -ForegroundModelCompletion` to test whether delivering one prepared model result earlier in the frame shortens settlement within the same budget. Both runs record the delay between the worker preparing a model result and the scene receiving it.

Use `-PrefetchLookahead` to test reprioritizing a small set of models already queued for the next live admission wave. The app report records actual priority submissions and whether each was ready when its consumer claimed it.

Use `-Phase cold -JoinDiagnostics -DriveObstaclePrefix` to check first-movement collision when new obstacles arrive after the worker captured the area. The app report records reused records, appended records, and any full rebuild.

Add `-DriveObstacleSparse` to allow the worker result to be reused with a small number of changed obstacle poses. The app report counts explicitly repaired rows and retains the full rebuild for other changes.

Use `-Variant gpu-skin-pick` to select GPU skinning with on-demand posed picking. Add `-PointerProbe` to each comparison run to cast eight selection rays per idle and movement window on a fixed 160 ms schedule. The probe ranks nearby visible skinned creatures at each window's start and cycles through their screen positions with fixed pixel offsets. Receipts include the selected ranks, hits, query timings, and any GPU shape refits or reuse that occurred during those rays. The probe sends no input events and leaves the existing waypoint route in control.

Use `-RouteLaps 3 -TimeoutSeconds 360` for a sustained headless check of the
doubled-density fixture. Each lap records the confirmed waypoint arrival,
return to spawn, and complete scene publication before the next lap begins.
Cold and warm runs use the same lap count. Timed rendering modes use one lap.
