# Native level-up core

Status: **partial native core verified against the owned local server**. The
overall migration and complete moving-world performance goal remain active.
No public server was contacted for this milestone.

## Implementation

`systems/server_level_up.gd` presents Class, Abilities, Skills, Feats, Spells,
Companions and Review in an independently movable native window. Level Up
appears in the quickbar and character record only when actual server state
allows it. Reopening an existing draft raises that window. Companion names
and filters are committed together when navigating, including text not yet
submitted with Enter. Menus continue to allow outside world input and WASD.

`tools/level-up-service.mjs` reuses the unchanged progression helpers in
`src/character_level_up.js` and the existing typed session transaction in
`electron/network_game_session.mjs`. It warms/caches progression resources,
requests actual available classes and raw skill ranks, and owns private
view/control handles. Native input cannot supply a trusted proposal. Ability
cadence, class/cross-class costs and caps, normal/bonus feats, master groups,
prerequisites, Wizard's shared two-spell pool, domains/school and companion
fields use the original helpers. Changes to the canonical snapshot, controlled
actor, world or area invalidate a draft. Duplicate/in-flight edits are blocked.

Finish sends the existing binary proposal and waits for the actual server
reply. No optimistic level, XP, ability, feat or spell changes are written to
the live actor. Acceptance also waits for replicated class advancement before
allowing another draft. Rejection and uncertain replies are terminal/locked
until an appropriate close/reopen or late server resolution. The character
record's subscription is restored after cancellation or acceptance.

## Evidence

- `reports/native-level-up-local-v3.json`: **16 dialogue/examine checks and 42
  level-up checks pass**. Real server cancellation preserves level 15; Wizard
  15→16 and then Fighter 1 are accepted. Intelligence increases 19→20,
  Concentration 18→19→20, spells 10/16 are learned, and the second level selects
  grouped feat 72 plus actual granted Fighter feats. Native inventory/record
  windows coexist with the draft while actual WASD moves the character.
- The actual server-exported BIC independently confirms both classes, all six
  abilities, every raw skill rank, proposed feats and learned spells. Its hash
  equals the saved BIC hash:
  `d7a56c29c1735d79833c3f4d0785700f3de0e63936c0bb87afb993fd840d81fc`.
  The vault is a fresh external temporary regression directory. The installed
  wizard is read-only; test XP 136000 is applied only to a derived in-memory
  character. Source hash:
  `00fd8475c7795069ff2be7e18130a3b6a658e98e9dfc9442c0cff6a955a06c9b`.
- The final run disconnects and exits Godot with code 0, no native error or
  renderer errors, and zero pending record images/inventory icons. The test
  result is rechecked after process output closes, so shutdown errors can no
  longer be hidden by an earlier successful gameplay result.
- `reports/native-level-up-node-v3.log`: **49 cases pass** across the new
  service, existing progression/model/writer/session, bounded protocol,
  character-record service and integration-evidence checks. The unchanged
  writer suite retains its 48 original-binary execution comparisons; no fresh
  original-process profiling or mutation occurred here.
- `reports/level-up-ui-native-v4.json`: **15 native UI checks pass**, with a
  clean dedicated engine log. Character-sheet (**18**), spellbook (**22**) and
  world-scope (**17**) regressions also pass in the `level-up-*-regression-v1`
  reports. These are authored UI/ownership checks, distinct from live server
  acceptance. The final live v3 run covers the final scripts and stricter gate.
- `native-level-up-local-v3-level-1.png` and `-level-2.png` were inspected:
  full Review contents/buttons and both spell/feat summaries are readable.
  This small-room instantaneous FPS is not a complete-world benchmark. The
  unrelated project editor was preserved throughout.

Failures are retained. Local v1 accepted the Wizard level but the test chose
installed Workshop feat 24750, absent from the vanilla server. Its rejection
was correctly displayed. The fixture now traverses actual groups to select a
base-game feat; this does not change the user's global mods or client rules.
v2 passed and v3 repeats with final shutdown acceptance. A host callback's
missing `async` initially prevented startup; syntax validation and real launch
now pass.

## Dialogue regression and subsequent cleanup fix

The separately authorized `native-dialogue-approved-v2`/`v3` runs pass all 16
behavior checks, including the server-authored attunement, portrait, byte RGB
colors, name/custom tokens, reply/end/abort scripts and overhead feedback.
They also expose exit warnings: one CanvasItem, seven textures and 20 ObjectDB
instances. Their earlier `success:true` predates the corrected final-output
gate and is **not clean lifecycle acceptance**. The stricter
`native-dialogue-cleanup-diagnostic-v2.json` correctly reports failure after
identical behavior checks; verbose orphan details are retained. A delayed
world/UI shutdown experiment did not fix this and was removed. The longer
final level-up run includes the same 16 dialogue checks and exits cleanly;
that did not resolve the short-run leak at that checkpoint.

Follow-up: [NATIVE-MAP-JOURNAL.md](NATIVE-MAP-JOURNAL.md) identifies and fixes
the unparented unopened-inventory AC label. The actual short dialogue test
`native-dialogue-cleanup-fixed-v1.json` now passes all 16 checks and exits
cleanly without opening inventory. Earlier failed reports remain unchanged.

## Remaining coverage

- Actual local domain/school/new-caster/animal-companion paths, all prestige
  and epic branches, replacement-spell eligibility and HP-roll preferences.
- Real pending level-up across transitions/reconnect, delayed/lost replies and
  broader custom-content/server restriction combinations. Authored rejection,
  uncertainty and stale-owner tests do not substitute for those integrations.
- Physical mouse/keyboard gestures, complete original skin/fonts and layout
  behavior at small resolutions; map/journal/party/creation and full NUI.
- Incomplete particle providers/textures,
  all remaining migration modules, complete moving-scene >=60 FPS acceptance.

Run `join-local.ps1 -LevelSmoke -Report <unused-name>.json` against the owned
GodotRecords fixture. It changes no installed character or user vault. The
local host also accepts `--native-verbose` for a separate diagnostic engine log.
