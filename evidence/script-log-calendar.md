# Timestamped script logging and calendar bindings — 2026-10-17

Target NWN:EE89.8193.37-17 x64, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original executable/assets/Ghidra project remain unchanged. Source assets are
resolved from the existing installation. Goal remains ACTIVE; single-player first.

## Native evidence

The independently read command table maps WriteTimestampedLogEntry560 to
**ExecuteCommandPrintLogEntry1405397b0..140539a61**. Its mandatory StackPopString
call at53980a precedes all side effects; failure returns -639. Successful calls:

- GetCurrentTimestamp at53983f, then Emit at53989b with flags1/2,
  function ExecuteCommandPrintLogEntry, servercore source path, line0x62bf,
  format `[%s] %s\n`. Timestamp/text are C strings, including embedded-NUL stops.
- GetDebugMode at5398ab. Only nonzero mode queries config BOOL
  `server.log.debug-mode-sends-to-players.enabled`, fallback false (5398f8).
- If both gates hold, Format at539998 uses `[ServerLog:%s] %s`; GetPlayerList
  at5399a8 captures count once. Each live pointer is read in original order,
  including duplicates and later pointer mutations. GetNWSMessage5399ee and
  DebugInfo_String5399fd run for every entry; send return is ignored.
- Original temporary strings/config allocation are cleaned on their actual
  branches. Native ownership is captured and checked separately from JS GC.

GetDebugMode14055b410..41a reads AppInternal+100f0. Constructor14055c300
zeros EBP at55c31d and writes that field at55c47d. The local logging runtime starts
at that proven zero value. Config fallback remains false. This does not implement
the original server's complete configuration/debug-console lifecycle.

CExoDebugInternal::GetCurrentTimestamp140165230..165335 calls time64 at16524d,
ctime64 at165257 and sprintf at16526b with `%.19s`. Original truncation,
length/assignment/allocation, replacement and empty cleanup execute in the oracle.
The pointer is narrow bytes despite the decompiler's guessed CRT wide name.
Runtime uses local wall-clock fields, fixed English names, space-padded day and
zero-padded hh:mm:ss; e.g. `Thu Jan  1 00:00:00`. Diagnostic ISO timestamps are
independent metadata. No locale-dependent JS formatter or game clock substitute.

DebugInfo_String1404d5ce0..5da3 creates message(length+4,INVALID,1), copies
the explicit-length owning string, writes CExoString with width32, and obtains
the payload. Failure returns0 without transport. Successful transport at4d5d8f
uses PLAYER_ID at player+48, major33/minor5, returning the transport result.
`sendDebugInfoString` preserves these boundaries. The local runtime reuses its
message buffer, writes/reads the existing native message-body codec and emits
the canonical recipient ID. It does **not** invent a PLAYER_ID or transport
envelope. Native client debug-window handling remains unmapped: a retained
`script-log.local-delivery` diagnostic identifies the local system-log projection.

Calendar commands13/14/15 map to complete wrappers51fb60..fb9c,
51fb20..fb5c and51fae0..fb1c. No args are popped; each obtains the live world
timer and pushes its native integer result (-638 on failed push). Year getter
597720..759, month597500..534, day597360..38e all call complete calendar-day
getter597230..29e. Its uint64 counter division, DWORD offsets, negative-wrap
normalization/positive carry and exact paused==1 path execute unchanged.
Calendar months have28 days; year>32767 falls back to1340. New bindings reuse
the existing WorldTimer instead of module start fields or wall-clock dates.

REA dossiers are `rea-script-print-log-entry-owner.json`,
`rea-debug-timestamp-internal-owner.json`, `rea-server-debug-mode-getter.json`,
`rea-server-internal-ctor-debug.json`, `rea-server-debug-info-string.json`,
`rea-calendar-script-wrapper.json`, `rea-calendar-{month,day}-script-wrapper.json`,
and `rea-calendar-{day,month,year,monthday}-getter.json` in backups/animations.
The DebugInfo receiver name searches returned no match; this is not evidence
that the native receiver is absent.

## Verification

- **183 original-code logging cases PASS**:134 complete wrapper cases,
  nine complete timestamp cases,40 complete sender cases. Includes failed pop,
  empty/NUL/CP1252 strings, non1 debug modes, both gates, zero/negative/duplicate
  player counts, count/pointer mutation during sending, and ignored send failures.
  Captured boundaries are VM, CRT time/formatting, logger, config, string codec
  and transport. No full native logger/filesystem/network claim.
- **684 original-code calendar cases PASS**: complete wrappers/getters and
  original clock normalization, including uint64 epochs, DWORD wrap, pause0/1/2,
  multiple day lengths, calendar/year boundaries and integer-push failure.
- **36 focused tests PASS** (`script-log-calendar-focused-v1.txt`): logging,
  calendar/world timer, existing script utilities/message text, diagnostic storage
  and script-load-failure handling. No full ~2,000-test suite rerun for this change.
- Installed `installed-script-log-v1.json` PASS: four actual parsed-NCS560
  calls exercise all gates and canonical identities. Untouched installed
  x2_s2_addprop (active spell654) receives event19 with a real equipped item and
  invalid cast item, reaches its authored invalid-recipe logging branch and
  leaves the target/properties unchanged. No engine errors/warnings. Fixtures
  isolate startup/general AI and control wall time; no per-spell production path.
- Installed `installed-script-calendar-v1.json` PASS: three parsed-NCS queries
  read Prelude's actual1372/6/1, then33 queries replay11 original-code timer
  states, with no new objects, errors or warnings. Mount scripts' complete
  lifecycle remains outside this check.
- Final build PASS (`script-log-calendar-build-v1.txt`), existing chunk warning.
  Offscreen isolated client casting check PASS (`script-log-calendar-casting-ui-v1.txt`,
  session32303 terminal0 consumed): spellbook, radial self cast, slot consumption,
  hotbar targeting, cast clips, cancellation and counterspell radial/live state.
  Chromium shutdown GPU text is retained. This smoke check does not exercise
  the optional debug-log window branch or prove native window-layout parity.
- Active impact auditv59:840 spells,596 loaded impacts,**45 unbound calls /
  22 load failures**, down from49/22 before these four bindings. Audit exit1 is
  intentional because load failures remain. Binding counts are not spell acceptance.

Oracle fixture failures are retained in native-script-log-v1..v3 logs: an
incorrect synthetic AppManager/AppInternal pointer chain and a return-instruction
range were corrected; v4 passes. Calendar-v1's excluded day-getter return
sequence was corrected from saved assembly; v2 passes. The first focused log
test expected too few config/format frees; actual native cleanup count was used
to correct that assertion. No production behavior was changed to hide failures.

GetResRef582's complete wrapper dossier is saved but remains unbound; native
generic-object versus module casts/resource-reference storage must be mapped
before exposing it. Other effects, per-part rendering, combat, death/UI,
inventory/save and full campaign acceptance remain open. No subsystem/goal
completion claim.

Verified checkpoint `backups/script-log-calendar-20261017-v1.zip` contains
11118 files/160167756 bytes. Writer verified every archived length/SHA256;
session42820 terminal0 consumed, `script-log-calendar-checkpoint-v1.txt`.
This verification note was added after sealing.
