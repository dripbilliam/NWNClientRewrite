Private Tracy manual launcher framework, source-only until explicitly prepared.

After BOTH root engine/DLL build receipts succeed:
  node tools/native-tracy/live/prepare.cjs <fresh-label>
  node <stage>/source/materialize.cjs <stage>/config.json          (dry-run)
Root alone may later materialize with --execute and perform native parser,
capability, connected-capture and lifetime checks. No runtime is started here.

launch.ps1 defaults to reporting readiness. Explicit -Launch additionally requires
an exact-stage native acceptance receipt: stageManifestSha256, nativeParsed:true,
functionalPassed:true, bridgePassed:true, lifetimePassed:true, and manuallyReviewed:true.
It opens only the normal menu/server browser. The user chooses a server and logs in.
It neither captures Tracy automatically nor logs tickets, settings contents or login data.

Current source factory explicitly selects engine-build-c/receipt.json. Engine A
and source plans manual-source-a/b are retained historical evidence and must not
be materialized: engine A's smoke reached its result but failed during shutdown.
Engine C's plan ancestry C->B->A is hash-checked through every parent; the DLL
remains exactly from A. Native source pins, compiler/profiler options and accepted
reconstruction/overlay must agree across that chain, with pinned shutdown fixes.
This ancestry check never substitutes a later binary for a recorded earlier hash.

Actual native runtime selection uses a diagnostic descriptor containing the real
MSVC/PDB Tracy engine and instrumented DLL hashes. Normal startup verification
remains active for executable path, capabilities, parsed policy and all16 flags.
The original host filename is retained solely for dependency/install resolution.
There is no executable-spawn substitution and no normal10b/485 identity claim.

The private project copies active code/native/cache manifests independently.
Only five exact named/hash-pinned immutable REA dossiers may be hardlinked.
No original game assets are bundled. Documents/NWSync remain ordinary user sources.
Rebuild through the installed normal ensure helper is deliberately unsupported;
the private diagnostic build manifest cites the actual root build receipts instead.

Source tests do not establish native startup, pixels, capture validity or FPS.
Instrumented capture is diagnostic, not an accepted normal-performance comparison.
