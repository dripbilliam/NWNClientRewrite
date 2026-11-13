SOURCE ONLY. No full capsule cloned, compiler started or engine launched.

The immutable base is camera-final-d-current-a/production-selection.json,
SHA ebb933353b75853ce1ea86a61c0cf92d6a0fbf4e5285e3eee58b616c80c2b2fe.
Its actual engine is10b24711..., sourceea3469..., kernel485741af..., resourceF2.
All25 recorded base user flags plus explicit profilingOFF and separate render
thread are preserved; actual postprocess mask28 is NOT replaced with default16.

Metadata/source validation only, permitted while native work is held:
  node godot-client/tools/native-render-gap/scene/static-prefix-fixture-capsule-a/prepare.cjs --mode=source-check

AFTER root grants another functional/native slot and a separate adapter build
exists with exact reviewed contract/source pins (currently E, still uncompiled):
  pwsh -NoProfile -File godot-client/tools/native-render-gap/scene/static-prefix-adapter-a/build-private-e.ps1 -Label <fresh-build-label> -Build
  node godot-client/tools/native-render-gap/scene/static-prefix-fixture-capsule-a/prepare.cjs --mode=prepare --label=<fresh-fixture-label> --build-receipt=<absolute-build-receipt.json> --build-receipt-sha=<exact-sha256> --dll-sha=<exact-sha256>

Explicit future reviewed revisions may be supplied only as exact pairs:
  --adapter-contract=<file> --adapter-contract-sha=<sha256>
  --candidate-manifest=<file> --candidate-sha=<sha256>
  --fixture-manifest=<file> --fixture-sha=<sha256>
The build receipt must name the same contract and exact source-pin list.
No mutable latest selector is used. No semantic acceptance follows from build.

The preparer prints fresh manifest path+SHA and a FROZEN execution/run.ps1.
Run that exact copied script with the printed manifest pin:
  pwsh -NoProfile -File <out>/execution/run.ps1 -Manifest <out>/manifest.json -ManifestSha <printed-sha> -Run
Use escalation only if the authorized process/module observation needs it.

Exact Godot CLI is in manifest.cli. It uses an independently copied engine,
--headless --render-thread separate --path <out>/project --log-file <out>/engine.log
--script res://tests/static_prefix_observer_fixture.gd -- <all base flags>
--candidate-script=res://tools/native-render-gap/scene/static-prefix-candidate-a/candidate_factory.gd
--report=<out>/fixture-report.json --observer-startup=<out>/runtime-startup.json
--observer-ready=<out>/observer-ready.json

The observer wrapper inherits actual fixture-v2 run() unchanged. It waits at
startup until the frozen runner has verified owned PID/FILETIME, exact loaded
engine and cursor/particle/resource DLL paths+hashes. All engine/user data uses
private process APPDATA/LOCALAPPDATA and custom_user_dir; TLS uses the existing
private certificate fixture. No global environment/preferences are changed.

Code, native DLLs, proof sources and engine are independent byte copies.
Only five exact immutable visibility REA dossier names may be hardlinks.
The base is never modified. The runner verifies every prepared pin before/after,
retains failed outputs, rejects missing/false reports even when engine exit0,
requires all26 paired cases, zero wrapper failures, four actual native positive
cohorts and463/1/0 scanned/admit/fallback for the large canonical case.
Unknown errors/warnings/leaks and forced cleanup are not clean acceptance.

This code has NOT been Godot-parsed, PowerShell-parsed, compiled or run.
Light JavaScript metadata/negative gates are separately recorded. Root owns
activation seam review and runtime authorization. No FPS or speed claim.
