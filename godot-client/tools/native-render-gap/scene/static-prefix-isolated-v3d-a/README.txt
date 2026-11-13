SOURCE-ONLY V3d isolated observation/acceptance framework.
No capsule clone, compiler, Godot, native/headless or PowerShell job authorized.
GDScript and PowerShell sources have not been parsed or run.

Selected input is B4/F, still UNPARSED/UNCOMPILED/UNEXECUTED/UNACCEPTED:
 B4 manifest98e80d4ca5f9140e88252a8615b1cdb64197343c9d69f5fc4bc05b089259fb21
 F contractb29a15b0ca7d67d28a33f4938e8bce37ff582faae6db812d2e3163bf519b6898
 V3d manifestb3be1bfa5e3551a062ac853047d3a4af9eedc8b68ff631bc6c0eb2671532fbfe
Its parent fixture manifests3/3b/3c are recursively validated and copied.
The later transactional-skip issue may reject B4/F: no pass is assumed.

Source metadata only:
 node godot-client/tools/native-render-gap/scene/static-prefix-isolated-v3d-a/prepare.cjs --mode=source-check

AFTER new explicit free-PC authorization and an exactly pinned future F build:
 node godot-client/tools/native-render-gap/scene/static-prefix-isolated-v3d-a/prepare.cjs --mode=prepare --label=<fresh-v3d-label> --build-receipt=<absolute-file> --build-receipt-sha=<exact-sha256> --dll-sha=<exact-sha256>
 pwsh -NoProfile -File <out>/execution-isolated/run.ps1 -Suite <out>/isolated-manifest.json -SuiteSha <printed-sha256> -Run

Preparation reuses frozen assemblerB ONLY to create the independent source/native
base once. Its V2 runner is NEVER called. All new V3d source/runner/policy is
appended in fresh paths and a separate isolated-manifest; seed pins/manifests
remain untouched. Code/native/engine copies are independent, except the five
explicitly named immutable REA dossiers allowed by assemblerB.

31 cases (27 V3 +2 V3b +1 V3c +1 V3d) each run baseline THEN candidate in separate
owned native processes:62 children, strictly sequential. Each has fresh reports,
checkpoints, module observations, APPDATA/LOCALAPPDATA and working user directory.
The startup barrier verifies exact engine, PID/FILETIME and actual loaded cursor,
particle and resource DLL paths+hashes. Owner proof records actual original
Collision script for baseline and pinned B4 owner script for candidate. Missing
class/owner/checkpoint/report or crash/nonzero/forced exit stops the queue.
Complete semantic failures are retained and pair-rejected, never a substituted
baseline pass. Expected script errors may be observed with natural exit0.

Comparisons require exact result_bytes, event order, post-state, checks and
before-call checkpoint; baseline actual_use must be{}, candidate counters must
prove actual calls and no wrapper failure. The V3d last-state test additionally
requires its actual payload PREDELETE, FAR->near mutation and later old-second
query in order. Scratch/Object-key/element-payload branches require witnesses.

error-policy.json is deliberately fail-closed. Six potential-error cases require
explicit review even if observed logs are empty. Any other observed non-startup
output/error also requires review. A reviewed policy must pin BOTH roles' exact
engine/stdout/stderr SHA256 observations and current engine/candidate/contract/
fixture scope. Only capsule path prefixes and exact reviewed role-frame lines
can normalize. No message/category/extra-frame/ordering/blank-line deletion is
allowed. Unknown errors/warnings, crashes, leaks or missing checkpoints reject.

After inspecting preserved initial outputs, compare under a NEW policy+label:
 node <out>/execution-isolated/compare.cjs --phase=case --suite=<manifest> --suite-sha=<sha> --case=<case> --policy=<reviewed-policy-file> --policy-sha=<sha> --comparison-label=<fresh-label>
 node <out>/execution-isolated/compare.cjs --phase=suite --suite=<manifest> --suite-sha=<sha> --policy=<same-policy-file> --policy-sha=<sha> --comparison-label=<same-label>
Every case needs the same reviewed-policy SHA for the final suite result.
No policy review requires reusing/overwriting native output or acceptance files.

Full hashes are checked before/after the suite. Per-child checks cover every
prepared source/runtime/proof file except the five immutable linked REA dossiers,
which are covered by the full suite-boundary hashes. Each actual engine/module
is also observed by path/hash before startup release. No hot timing/FPS metrics.

An isolated suite PASS is NOT complete adapter acceptance. V2 canonical fast-use
positive proof, current-world correctness, performance and product activation
remain separate. Source checks/synthetic comparator tests are NOT native tests.
