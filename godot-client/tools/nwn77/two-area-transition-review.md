# NWN-77 two-area static merge transition check

The headless original-asset transition fixture passed **32/32 checks** with the current opt-in `--static-scenery=merged` route. Report: `.cache/nwn77/two-area-capture-a/report-final.json`, SHA-256 `8496f95b4cce73964ef8bd3e92a3161ee03044ed5b1709fc0db7b153ff7d97df`. The private Core E executable SHA-256 is `753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b`. The report pins all AreaStream/static-merge fixture source hashes and the extracted capture-area SHA-256 `8e72f8e0348ff664177aeb1d146d0184f4c08b79aebeda18dd32dabd867cc7c4`; the capture extraction script checks the previously staged recording SHA before writing its immutable area input. No FPS was measured.

`tools/nwn77/two-area-prepare-capture.cjs` selected the first `raw-world-begin` for the two distinct original areas in the saved recording: `udcitydist1a` generation 2 (225 tiles) and `gs_enter` generation 1 (9 tiles). `tools/nwn77/two-area-recorded-transition.gd` mounts the recorded original-resource catalog, opens them in order A→B→A through the actual `AreaStream.open_network_area`, and selects the same native lighting/surface flags as the matched normal-client static pair. It checks each generation, complete original tile publication, settled merged owner, source-ID lifetime separation, A model and merged-draw weak-reference release after B, zero old groups/worker IDs at both transition starts, identical A reentry coverage, and final worker/owner drain.

| Area | Local generation | Rendered tiles | Active suppressed source draws | Active merged batches | Active member surfaces | Pending workers |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `udcitydist1a` | 1 | 225 | 933 | 220 | 1,086 | 0 |
| `gs_enter` | 2 | 9 | 71 | 19 | 81 | 0 |
| `udcitydist1a` | 3 | 225 | 933 | 220 | 1,086 | 0 |

The first and third area counts match the existing normal-client original-scene ON snapshots. All three area reports have zero terrain errors. The environment profiles selected `ttu01__ref`, `ttr01__ref01`, and `ttu01__ref` respectively. The separate local `dense_a→dense_b` report at `.cache/nwn77/two-area-a/report.json` correctly rejected its own coverage gate: its original `ttr01_g01_01` surfaces all used non-native materials in that harness, so no merge occurred. The first recorded-area attempt without normal native-lighting/surface flags also rejected every otherwise eligible surface as `material-not-native-static`; its report is retained at `.cache/nwn77/two-area-capture-a/report.json`. These are fixture setup results, not production regressions.

Run the passing fixture from the project root with:

```powershell
& .tools/native-core/Godot_native_core_e_win64.exe --headless --path . --script tools/nwn77/two-area-recorded-transition.gd -- --capture-areas=.cache/nwn77/two-area-capture-a/areas.json --report=.cache/nwn77/two-area-capture-a/<new-report>.json --static-scenery=merged --native-lighting=enhanced --native-surface-output=true
```

The JSON `success`/`checks` fields are authoritative: the Godot process returned exit code 0 even in the two intentionally rejected fixture setups. This check is at the AreaStream/recorded-catalog boundary. It does **not** exercise full `LiveWorld` area retirement, network authority, picking after a live transition, or GPU visual appearance. The remaining NWN-77 acceptance is a no-focus original-scene visual/functional transition with representative blended/cutout/fog/shadow and picking checks, followed by matched performance evidence before changing the default.
