# Spell dependency utilities — 2026-10-16

Target NWN:EE89.8193.37-17 x64; SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install/Ghidra project remain unchanged. No original binary/assets copied.

Bound PrintString1, VectorNormalize137, GetAreaFromLocation224 and
GetFacingFromLocation225; existing GetPositionFromLocation223 shares the same
native location-access owner. No module/spell-specific behavior or object IDs
are introduced. The active spell-impact audit falls from83 to80 unbound commands;
22 missing resources remain. GetAreaFromLocation adds a binding outside the
current impact-script dependency list, so four new bindings remove three rows.

## Native execution and REA cross-check

`scripts/inspect-native-script-utilities.py` executes **1,809 original wrapper
cases**, including failure/unknown-command cases. `native-script-utilities-
observations.json` records raw FLOAT bits, typed transfer outcomes, releases,
and logging metadata. VM transfer/ownership, common debug logging and floating
status notification are explicit captured lower boundaries. Original atan2f,
vector normalization and its nonnegative sqrtf paths execute. Finite input
FLOATs, SSE dispatch0 and nearest rounding without FTZ are the validated scope;
this does not establish exceptional atan2/errno or whole-VM/logger parity.

- LocationAccess **140535600..140535710** reads position at+0, area ID at+18,
  and raw orientation at+c. Facing computes atan2f(Y,X)*FLOAT57.2957763671875,
  then normalizes the full vector and adds360 only if its Y is negative. It
  returns a FLOAT, with no integer rounding or compatibility-angle shortcut.
  Signed-zero, near-unit, underflow and overflow cases are preserved. The raw
  area ID is returned without resolving it or allocating an object. Native
  pop failure=-639, push failure=-638 and successful ownership release are
  recorded; transfers/deallocation remain lower boundaries in the JS binding.
- VectorNormalize **14054ab60..14054ac2d** explicitly returns a fresh+0 vector
  for exactly-zero input. A nonzero vector whose squared length underflows to0
  instead reaches **140230920..1402309f4** and returns(+1,+0,+0). Near-unit
  tolerance, FLOAT operation order and exceptional arithmetic results from
  finite magnitudes match the captured raw bits. A first renderer-basis
  implementation introduced an incorrect negative-zero Y in the fallback;
  the oracle caught it. The final shared native-XYZ helper avoids that basis
  conversion and supplies both normalization and location-facing adjustment.
- PrintString **1403147c0..1403148cb** uses fixed format `%s\n`, or
  `PRINTSTRING: %s\n` only for private optional raw prefix value1. Other values
  do not select the prefix. Active nwscript exposes only the required string,
  so its engine binding uses the native default0. Embedded NUL truncates the
  C string; user percent sequences remain literal. Logging flags(1,2), native
  function/file and source lines150/154 are retained in durable informational
  diagnostics. It does not insert debug output into gameplay chat. Native
  logger filtering/sinks remain a host presentation lower boundary.

Supported typed-body comparisons cover730 location results,714 normalization
results and121 successful logging records. The additional original cases test
wrapper failure/unknown-command/ownership behavior, not a new implementation of
the VM's internal return-code machinery. `script-utilities-native-tests-v2.txt`
passes all focused tests plus prior location constructor/GetLocation regressions.

The new persistent REA connection independently supplied all three complete
function dossiers; addresses/mnemonics and boundaries match the static capture.
Sources: `resumed-spell-command-bodies-v1.txt`,
`resumed-vector-normalize-bodies-v1.txt`, successful sqrtf head captures,
and `rea-{location-access,vector-normalize,print-string}-dossier.json`.
Failed exploratory leaf-range requests are not validation.

## Installed and rendered validation

`scripts/probe-installed-script-utilities.mjs`, final
`installed-script-utilities-v2.json`: PASS. Real parsed NCS225/224/137/1 on an
installed character/module preserves canonical PC/area identities, computes
facing from stored vectors despite intentionally different compatibility angle
metadata, returns vectors through the VM's three FLOAT cells, and records literal
NCS PrintString output. The registry allocation cursor does not change. This is
an engine-path probe, not proof that every authored spell using a helper finishes.

**1,763 tests PASS**, production build PASS. Existing rendered spellbook,
radial casting, hotbar targeting, slot consumption, animations/cancellation and
counterspell UI regression PASS. Logs: `script-utilities-full-tests-v1.txt`,
`script-utilities-build-v1.txt`, `script-utilities-casting-ui-v1.txt`.
Fresh active inventory: `spell-ecosystem-active-audit-v37.json`; static binding
presence does not imply complete branches, successful live casts or campaign
readiness. The22 missing impact resources still give the audit a nonzero exit.

Next work remains the spell ecosystem, then combat and campaign play/fix work.
REA has already located CopyItem and the GetHasSkill/immortal/area query owners
for follow-up. These are research results, not implemented commands. The user
requested resumption; do not reinstate the historical pause instruction.
