# Small support correctness fixture

`check_support.mjs` stages the ten-script dependency closure, exact reference
geometry/triangle, three fixtures and the already accepted `672bd24a` DLL into
a fresh private cache. It never invokes a native build/Ensure hook, imports the
client or loads world assets. It defaults to **stage only**. Existing output
directories and receipts are refused; each invocation uses a new directory.

From the repository root:

```powershell
node godot-client/tools/native_parity/performance/support/check_support.mjs --stage-only
node godot-client/tools/native_parity/performance/support/check_support.mjs --run
```

Optional arguments are `--out=<fresh directory below godot-client/.cache>`,
`--dll=<existing file with the exact accepted hash>` and
`--modes=native,gd,missing,setup`. The default DLL is the preserved immutable
`whole-character-client-v3` copy. The shared `.cache/native-kernel` DLL is an
older binary and is not substituted. The runner selects only the already
reviewed atlas engine through the read-only launch selector. Missing or changed
source, proof, DLL or engine files cause a refusal; nothing is rebuilt.

The current-source integration's ordinary default launcher can select the
different shared `b3f59129...` DLL. This support change was **not validated
against that binary artifact**. Its existing build manifest records the same
`scene_geometry.hpp` hash (`9eefc170...`) and matching registration source, so
the source policy appears available there; that does not replace a binary
correctness check. `shared-dll-source-audit.json` records the read-only evidence.
The combined diagnostic capsule and this runner deliberately retain672 for a
comparable acceptance. No shared DLL was replaced or rebuilt.

Use `--run` only at an authorized small CPU-check checkpoint. It starts up to
four tiny sequential headless processes, each bounded to15seconds, stopping at
the first unexpected failure. No graphics, FPS or stress test is provided. The
expected counts are native115, explicit GD88, missing kernel5 and setup/reset8.
These fixtures already passed before relocation; moving them here alone does
not require another engine run. This new runner has only Node and stage-only
validation so far; root must review it before its first engine invocation.

Normal native and GD runs require zero diagnostics. The missing-kernel project
deliberately omits the copied DLL; exactly its three known FileAccess/extension
load errors are accepted. The setup probe deliberately passes one invalid
native vertex index, retaining exactly `Native collision vertex index invalid`.
Both fault probes must still pass every behavior check and exit0. Any other
error or warning fails. Invalid face data is never queried through GD in the
setup probe. `stage.json`, individual `run-<mode>.json`, the raw test results,
and final `run.json` retain source hashes, process output and fault classification.

`authority.json` pins current accepted production source, unchanged dependencies,
the exact before-reference files and fixture bytes, original full instruction
dossiers and the historical216-check freeze. Production query code remains in
its existing source owners; these tests do not carry a second runtime candidate.
Deliberate source/test changes need reviewed authority updates.

The case matrix compares exact f32 GD/native answers for ordinary30/94,
AABB masking, stacked/physical face order, inclusive edges, reverse rays and
endpoint ties. It also checks canonical/support owner isolation, cold preparation,
configure/reentry lifetime, metadata retention, legacy/missing-owner fallback,
missing provenance and actual native query/setup errors. Analytical plane-height
checks allow less than1e-6 rounding, separately from exact GD/native equality.
This proves the narrow face-query contract; no movement or frame-time benefit
is claimed.
