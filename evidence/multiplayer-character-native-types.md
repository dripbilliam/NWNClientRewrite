# Generated character admission and native GFF types — 2026-10-18

Previous goal turn: PROGRESS, spell-wheel checkpoint sealed. This turn: PROGRESS.
The full multiplayer goal remains ACTIVE and incomplete.

## Cause and correction

The generated level-one wizard was rejected with native strref66222 even without
the innate test records (v54 control). Its ClassList stored Class as BYTE0 and
ClassLevel as WORD2. The original loader requires INT5 and SHORT3. Equal numeric
values of other types do not pass these readers; the existing native class
defaults remain. That invalidates the relationship between class and wizard
feats/history. The native rejection code also covers eligibility/history
mismatches, so it must not be interpreted as only a literal total-feat limit.

`createCharacterBic` now writes Class INT and ClassLevel SHORT, omits first-level
LvlStatAbility, and uses history feat/known-spell struct type0 while retaining
permanent feat type1 and class known-spell type3. Feat counts or server rules were
not weakened. Existing malformed exports are not rewritten on network upload;
new creation/export uses the corrected writer.

## Original-game evidence

Read-only nwmain.exe build89.8193.37-17 x64, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Unmodified owned nwserver.exe SHA256
`98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6`.

- ReadStatsFromGff40f7f0 explicitly uses ReadFieldINT for Class, then
  ReadFieldSHORT for ClassLevel. The class setter is conditional on successful
  INT read. Complete retained pseudocode view is in
  `rea-network-character-read-stats-view.json`; other load owners remain broader
  than this patch's acceptance scope.
- ReadFieldINT1a1770 accepts exactly type5; SHORT1a17f0 accepts exactly type3.
  `inspect-native-character-field-types.py` executes both complete original
  reader bodies for690 cases. Label lookup and field-location lookup are
  captured boundaries. Original type tests, narrowing, default selection and
  found flag execute. This is not a full native GFF importer/ELC oracle.
- The existing complete SaveClassInfo413880..4145d8 oracle independently confirms
  these field widths, history struct IDs and first-level ability omission.
  See [class serialization](creature-class-save.md).
- Validator4bf210, branches4c0943..4c0b9f and4c152c, handles both selectable feat
  allowance/eligibility and permanent-feat/history consistency. Retained complete
  pseudocode view and prior bounded PE disassembly were reviewed, without
  treating the entire validator as implemented.

## Live server validation

ELC stays enabled. No server settings, executables, installed assets or original
Ghidra database were changed. Fresh BICs were generated into an OS temporary
directory, supplied through the existing unchanged network admission path, and
removed after observation. Private credentials remain in the one-use encrypted
loopback channel and memory, never files, environment or argv.

- v54 control, original creator/no innate records: character-rejected66222.
- v55 corrected creator: accepted and playing,904 GPU frames, no runtime error
  records. Native packet replay confirms canonical controlled creature ID,
  class10 level1/race0 and actual server-replicated wizard spellbook. It is not
  the installed high-level preset or a local replacement actor.
- v56 corrected creator plus two authored innate test records: admitted,2344
  GPU frames, but server-replicated innate pool is empty. The test stopped at
  the missing innate menu and sent no cast/assignment packets. Repeated harness
  missing-choice errors were retained in its diagnostics, not hidden as success.
  The harness now stops sampling after its first failed sample to avoid such
  repeated test-generated errors. No live innate cast is claimed.

The empty innate pool has a native explanation: fresh-player
LoadCreatureData4bb450 calls ReadStatsFromGff at4bb6a5 with its param5=1. The
SpecAbilityList read branch requires param5=0. Saved-module player load4babc0
calls at4baed7 with param5=0. The observed live fresh-PC behavior agrees with
the original path. Client-authored special abilities are not substituted for
server-issued powers. Next obtain a server-issued ability or controlled creature
through normal native feat/associate input.

Verified checkpoint `multiplayer-character-types-20261018-v1.zip`:13026 files,
246568840 bytes. Writer67177 terminal0 consumed; every entry length/SHA256
verified. Scope31 required present, forbidden0. Scope audit and this postseal
note are outside the archive. Private server profile/BICs/binaries/assets are
excluded; audited REA stderr is the only included runtime log.

Character rejection now emits `network.character-rejected` with the native
strRef, without character bytes/credentials. Current-area gameplay remains
unavailable until successful admission; the server owns the decision.

## Verification

Native690 reader cases pass. Installed-rules creation audit passes154 generated
race/gender/class combinations and11 canonical singleplayer imports, including
the corrected types/history metadata. Those are local importer checks, not154
vanilla-server admissions. v55 provides actual server admission evidence.
Focused creation/network tests and production build pass; existing presentation,
effect/audio, feat/item input and original-client concurrent-play gaps remain.
Final focused run:102 PASS (`character-admission-tests-v5.txt`); build PASS
(`character-admission-build-v1.txt`), harness/backend JS syntax PASS. Credential
audit v2 explicitly covers all recursive source/evidence/tooling roots and
research/current captures:3419 files, private hits0. v1's incomplete recursive
collection is superseded, not used as evidence of complete coverage. Test BIC
and its isolated OS temporary directory were removed. No QA process/session is
left connected.

Next: connect native feat activation and server associate/control state, then
verify innate wheel/type44 requests with an actual replicated server pool.
