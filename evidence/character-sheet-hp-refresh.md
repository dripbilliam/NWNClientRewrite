# Character-sheet subscription and maximum HP — 2026-10-17

Read-only NWN:EE89.8193.37-17 x64 nwmain.exe, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No original install or Ghidra project edits. This continues the single-player
spell/combat goal; campaign completion and flawless play are not established.

## Maximum HP

Complete GetMaxHitPoints140391850..140391e6f executes unchanged, with original
FNV hashing and captured lower feat/class/level-history/rules queries.
`inspect-native-maximum-hp.py` records 1526 cases. These include derived numeric
inputs from all39 installed local BICs, both include-feats settings, synthetic
PC/NPC/possession/CON/feat cases and active/custom rule overflows. All39 live
computed maxima match the original routine. Only palemaster.bic has a different
serialized maximum: saved114, live/native102. Its wizard10/pale5, CON14/cache2
and Deathless Vigor891 produce the existing min(pale,10)-4 bonus.

One actual implementation defect was found: native compares PC DWORD exactly1,
where JavaScript previously accepted any truthy value. Raw PC2 now follows the
native NPC path. Saved maximum is a snapshot, not runtime authority. A general
`character.saved-hp-snapshot-differs` warning retains both numbers and character
context instead of reporting a proven-correct calculation as session.failure.
No class, character, spell or campaign special case was added.

## Character-sheet owners

`src/character_sheet.js` ports these complete server/lifecycle owners:

- HandlePlayerToServerCharacterSheetMessage140444e00..14044502e: read signed
  page CHAR and canonical target ID for every subtype; overflow short-circuits
  underflow. Valid subtype1 checks permission, sends denial before mutation,
  decrements previous creature540 and increments new540 with signed DWORD
  wrapping, sets target/page and clears effect icons for pageFF. Other valid
  subtypes return1 without GUI mutation. No counter floor/cap is invented.
- PermittedToDisplayCharacterSheet1404bd020..1404bd0b5: requires a live server
  and target. Live player-info DM flag admits the target; otherwise only self
  or a direct associate whose master ID equals the controlled creature is
  permitted. Missing player info follows ordinary permission, not automatic
  denial. Party/faction membership is not a substitute.
- SetCreatureDisplayed1404be500..1404be584: changed target destroys/replaces a
  nonnull update; unchanged target retains identity. Null old update remains
  null; allocation failure is preserved by the provider boundary.
- StatsUpdate constructor14050a680..14050a789, destructor14050a790..14050a8b7
  and ClearEffectIcons14050a8c0..14050a983: initialized scalar sentinels,
  independently owned combat cache/skill bytes/lists, reverse icon release and
  capacity retention on clear. Unwritten padding/native pointers are not
  fabricated. JS backing allocation is lazy; observable constructor defaults
  remain native. Skill count comes from active skills data, narrowed to BYTE.

GUI construction is embedded at1404b79da..1404b7a32: targetINVALID, page-1,
owned StatsUpdate and forceDWORD1. Creature540 remains constructor0.
Queued ModuleSession requests preserve their canonical controlled actor;
changing control discards an old request rather than retargeting it.
The local adapter maps local DM ownership and canonical creature/master IDs;
it does not fabricate network PLAYER_ID values.

The frontend requests decoded page0/self on opening and pageFF/self on hiding.
The latter keeps the same target subscription (decrement then increment), as
the server routine requires; repeated opening does not accumulate consumers.
This is an explicit local frontend mapping. **Original client sender,
marshaling, initial request and tab/page choices are not independently mapped.**
Actual network transport, full statistics-update comparison/writer/replication,
allocation failure in live JS, controlled-character/client teardown and native
GUI presentation remain separate work. No wire/client parity claim is made.

## Validation

`inspect-native-character-sheet.py` executes1353 original-code cases:
976receiver,324permission,16target setter,5constructor,16clear,16destructor.
Tests compare ordered boundary calls, IDs, signed counters/pages, retained or
replaced update identity, initialized scalar bytes, active skill storage and
reverse icon release. Codec, lookups, player-info, allocation/free/memmove and
individually tested lower lifecycle owners are captured boundaries. Profiling
is disabled. JS lifetime comparison omits the native heap free itself.

Focused testv1 exposed two oracle-comparison fixture mistakes (heap free is a
JS boundary; icon-array allocation named "icons" is not an icon record).
Corrected focusedv2 passes8 tests. Initial full-suitev1 failed29 unrelated
minimal fixtures because eager skill-table access added a new dependency to
ordinary client lookup. Lazy backing allocation removes that dependency and
still requires real active skill data when the sheet is used. Failure logs
remain. Full-suitev2: **1918/1918 PASS**. Production buildv1 PASS with existing
bundle-size warning.

Installed combat-informationv2 PASS five checks: actual NCS synchronous
arcane/resistance cache rebuild; queued sheet open/same-target/pageFF/denial/
reopen; actual full creature-frame attack-buff cache refresh/removal; INT+4
prepared-slot resize/restoration. No fixture writes540. All registry identities
and allocation cursor are unchanged. One existing trap-check warning remains.

All39-character probev3 **PASS**, including cache and load stages with no error
records. Its2173 informational/warning diagnostics are retained, including
optional resources, unsupported item properties/visuals/inventory ownership
and the saved HP warning. This is not proof of complete imports or all item
effects. Previous failing load reports remain historical evidence.

Electron character-sheet UI checks initial targetINVALID/count0, panel opening,
three close/C-key reopens, switching to spells and opening again: canonical
self target, count1 without accumulation and dirty cache cleared by the real
frame. Screenshot inspected: character sheet visible with installed wizard
stats. No console or interaction engine errors. All diagnostics retained,
including the selector's rejected dungeonmaster.bic outside a DM session.
Startup is disabled and entry position is a test fixture; this is not campaign
acceptance. Native client/writer and full spell/combat/campaign gates remain.

Verified checkpoint: `backups/character-sheet-hp-1918-20261017-v1.zip`,
10264files/134896185bytes. Every archived length/SHA256 verified; checkpoint
session25289 terminal exit0 consumed. This verification note was added after
sealing; the archive retains pre-verification notes. Goal stays ACTIVE.
