# Pregame Character statistics — partial parity

The [detail-list follow-up](NATIVE-PREGAME-CHARACTER-DETAILS.md) supersedes this
checkpoint's interim description body. Its own current-source evidence covers
generated rows and original scroll ownership; full visual/UI parity stays open.

The typed native BIC preview now supplies the Character page's ability scores,
modifiers, HP, AC, alignment and XP labels through
`systems/native_data/pregame_record.gd`. The worker publishes `recordSource`;
the chooser prepares its active native dependencies before displaying numbers.
This is display data, not an authoritative creature/combat-state replacement.
No JavaScript model or rules calculation was added.

## Original evidence

Original `nwmain.exe` SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

Root `backups/animations/rea-native-pregame-character-v1.json` retains the
Character constructor/vtable observations, complete49,011-character pregame
SetData pseudocode, numeric assembly and related getters. Vtable+0x148 names
`1409bbfc0`;+0x150 names the separate world-object SetData `1409b6380`.
The earlier BIC import/base-constructor evidence remains in
`rea-native-pregame-skills-v1.json`. The additional
`rea-native-pregame-character-xp-v1.json` records the original rules constructor
loading EXPTABLE rows0–40 into its numeric cache and the AC label formatter.

The source import strictly reads SHORT ArmorClass/MaxHitPoints/PregameCurrent,
DWORD Experience, BYTE alignment and CExoString Subrace. PregameCurrent defaults
to MaxHitPoints. HitPoints and CurrentHitPoints are separate fields and do not
provide these preview labels. Constructor temporary HP is zero. The original
base-stats constructor's absent-field alignment defaults are GoodEvil85 and
LawfulChaotic15; BYTE alignment imports clamp to100. This describes missing BIC
fields, not character-creation defaults or received in-world effects.

Scores reuse the independently original-validated race/class import and native
modifier arithmetic. XP uses the original signed decimal display, active
EXPTABLE row at the byte-sized total level, localized labels314/315, and original
level40 maximum message10335. Subrace/race, alignment and class headings resolve
through the active tables/TLK. Missing dependencies stay pending; unavailable
XP data reports an error rather than guessing a threshold. Same-key resource
publication refreshes labels without rereading the BIC.

`scripts/inspect-native-pregame-character.py` executes the unchanged numeric
prefix of original SetData and the original alignment getter in an isolated
emulator. It stops before portrait/detail generation. Formatting, TLK and label
writes are captured services; initial imported stats are fixtures. Score inputs
come from the earlier original class/race instruction observations. Its72 cases
cover signed field boundaries, configured modifiers, active XP values, alignment
thresholds and the level40 maximum branch. This is not a whole import, rendering
or combat oracle. The observation file is
`backups/animations/native-pregame-character-observations-v1.json`.

## Current headless verification

| Run | Checks | Scope |
| --- | ---: | --- |
| `native-pregame-character-data-v2` |802| Original numeric-prefix comparison, strict field types/defaults, pending/error data |
| `native-pregame-character-worker-v2` |24| Native BIC integrity, selection ownership, worker shutdown regression |
| `native-pregame-character-skills-v1` |373| Earlier original skill/class-gain arithmetic and typed import regression |
| `native-pregame-character-spells-v1` |296| Earlier original spell enumeration/gain/minimum regression |
| `native-pregame-character-input-headless-v1` |14| Actual typed BIC, original control input at100/125%, labels, active table/TLK refresh and stale-selection cleanup |
| `native-pregame-character-chooser-headless-v3` |23| Existing selection/double-click/New/Cancel and legacy preview regression |

All1,532 checks run headlessly under exception traps with source/lifetime checks.
They do not accept artwork, fonts, cropping, visual appearance or GPU behavior.
The manually opened client was preserved. No public-server connection, visible
test window, focus change or mouse capture was used. Fresh graphical and owned
local-server checks of this change are still required when that session ends.

The first chooser compile checks are retained as failures: v1 lacked an explicit
String declaration; v2 used a reserved script keyword for a local variable.
Those isolated stalled headless processes were stopped; v3 passes after the
source corrections. Early emulator harness failures produced no accepted oracle
file. The old independent native startup heap exception is still unresolved;
passing current headless checks do not close it.

## Remaining work

- Continue the [detail-list follow-up](NATIVE-PREGAME-CHARACTER-DETAILS.md):
  source-generated pregame rows are connected; full disclosure, appearance,
  wrapped-row metrics, in-game variants and all gestures remain unaccepted.
- Compare original-client heading/title, fonts, geometry, colors, line spacing,
  portraits, artwork and source100/125% output. The input fixture's optional
  graphical path exists but has not accepted this change.
- Cover negative class levels, all source variants, malformed/missing custom
  rules, language/large-font modes and remaining pregame keyboard/role states.
- Run fresh owned authoritative admission/gameplay regression and mixed-client
  comparison; earlier local receipts describe their earlier source snapshots.
- Finish the full chooser and every other UI surface in the active goal. Native
  gameplay details, stability and complete UI parity remain unaccepted.

The verified rollback archive and current-source proof are recorded by
`tools/audit-native-pregame-character.mjs`. General porting remains deferred.
