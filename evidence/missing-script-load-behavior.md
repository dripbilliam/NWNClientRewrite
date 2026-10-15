# Missing named-script resources

2026-10-15. NWN:EE89.8193.37-17 x64, installed PE SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Read-only Ghidra and complete PE disassembly verify the native failure branch.
No Ghidra edits or installed game changes were made, and no replacement game
script assets were created.

## Resource audit

The installed Prelude module references script1 from OnHeartbeat in all five
areas. Four areas reference script2 from OnExit (including the starting room
and the next area). These are authored field values, not names invented by the
replacement. Neither NCS nor NSS exists in Prelude, active nwn_retail.key or
nwn_base.key catalogs, or the installed ovr folder; Prelude has no loaded HAKs.

`scripts/audit-missing-script-resources.mjs` reproduces that catalog/reference
audit and exports metadata only to
`backups/animations/missing-script-resource-audit.json`. It does not claim to
audit arbitrary external user overrides, servers or community installations.

## Native observations

- CVirtualMachine::ReadScriptFile `0x1402836a0..0x140283983` increments nesting
  depth and rejects depth8 or greater, restores the depth, and returns-633.
  It constructs the resource reference and calls the resource cache at
  `0x14028375b`. A null resource at `0x140283767..0x14028376e` takes
  `0x140283770..0x140283778`: restore depth and return0xfffffd86(-634).
  No ExecuteCode path runs. Ghidra's pseudocode stops at a cleanup thunk;
  `native-script-file-load-asm.txt` contains the complete instruction body.
- CVirtualMachine::RunScript `0x140283990..0x1402840c1` returns0 for an empty
  name at `0x1402839df..0x1402839e6`. It calls ReadScriptFile at
  `0x140283d5e`; a nonzero load result branches at `0x140283d65` to
  `0x140284011`, where native success flag r15d is set from zero esi.
  Cleanup completes, then `0x140284097` returns that failure0. RunScriptFile
  and its ExecuteCode invocation are bypassed. The surrounding event/caller
  continues; failure is not a replacement-client exception or fabricated script.
- CNWSObject::RunEventScript `0x1404998a0` resolves the script field, returns0
  for empty names, and otherwise returns RunScript's result with the canonical
  object ID and script event context. The event handler's remaining work is
  independent of a nonexistent script's body.
- CNWSDialog::CheckScript `0x14041a110..0x14041a26f` returns1 for an empty
  condition name. For a named condition it calls RunScript at `0x14041a20c`.
  `0x14041a211..0x14041a216` preserves a failed RunScript result and bypasses
  return-value extraction. Successful calls require an integer return value;
  absent/noninteger return data yields false. A missing condition is not
  automatically eligible. CNWSDialog::RunScript `0x14041c890..0x14041c9b8`
  calls the VM at `0x14041c98c` and finishes without making a failed action
  into a modal dialogue failure.

Captures: `backups/animations/ghidra-script-load-*.txt`,
`native-script-file-load-asm.txt`, and `native-script-dialog-load-asm.txt`.
This evidence establishes missing-resource behavior, not a fully reconstructed
native compiler, resource cache or general VM error/unwind implementation.

## Replacement behavior

ModuleSession.runScript is now the shared named-script entry for event scripts,
dialogue actions/conditions, damage/perception, area-effect callbacks and nested
ExecuteScript calls. A resolver RESOURCE_NOT_FOUND for resource type NCS returns
an explicit nonexecution result: executed=false, nativeResult0, loadError-634,
and no VM return cells. It records script.resource-unavailable with script,
canonical owner, context, cause and native result for every invocation. Generic
resource.lookup-failed records remain available as well. It does not call the
session-error/HUD interruption adapter for this native load-failure outcome.

Missing event/action scripts let the parent proceed; a missing DLG condition
returns false. Empty names do no work. Successful program caching is unchanged,
while rejected loads are removed from the cache so a later available resource
can be resolved. There is no negative-cache or script1/script2 runtime special
case. Corrupt NCS, archive read failures, unrelated missing resource types and
unsupported engine/runtime execution continue through the existing error paths.
Direct program loading remains strict; only named execution handles this case.

This fixes the replacement's behavior for these absent references. It cannot
recover nonexistent script contents, and it does not substitute guessed quest
logic or hide the absence from diagnostic records.

## Validation

- 1313 tests and production build pass. Six new tests cover per-attempt records,
  no instruction-budget consumption for unavailable programs, retry/late resource
  availability, successful caching, parent ExecuteScript continuation, DLG
  condition/action behavior, area transfer membership/ID preservation and
  propagation of corrupt/read/engine failures.
- The installed `scripts/smoke-area-transition.mjs` exercises two authored
  heartbeat attempts, both original reported door dialogue scripts, queued
  opening/closing and the generic transition NCS. Script1 attempts and the
  script2 exit return0/-634 and remain recorded. The transfer reaches m0q1b
  with no engine/script failures or session diagnostic errors. Result:
  `backups/animations/missing-script-installed-smoke.json`.
- Rendered Electron validation completes the authored dialogue exit reply,
  clicks/approaches the exit, loads m0q1b and returns normally to m0q1a.
  Player565 and door IDs2/45 survive. Seventeen unavailable-script attempts
  (heartbeats and both exit callbacks) are recorded with native failure results;
  none raises a session error or appears as a missing-script message in gameplay.
  No renderer errors occur. Capture/report:
  `backups/animations/missing-script-rendered.png` and
  `missing-script-rendered-smoke.txt`.

The rendered test still uses a stock character, an in-memory entry override,
disabled startup and a labeled preview sun. It is not full original-campaign or
multiplayer acceptance. Other resource, engine and presentation gaps remain
explicitly recorded.
