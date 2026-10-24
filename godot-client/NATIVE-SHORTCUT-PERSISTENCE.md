# Saved multiplayer shortcuts

Saved-character reconnect now has native integration evidence for inventory,
item-power, prepared-spell, skill and command shortcuts across all three pages.
The existing session/server export path supplies persistence; this milestone
validates that path with native controls rather than introducing a separate
client-side binding store. Full quickbar and migration parity remain open.

Run the owned local check with:

```powershell
./godot-client/join-local.ps1 -ShortcutReconnectSmoke -Report unused-test-name.json
```

An explicitly preserved original game can be named with `-PreserveOriginalPid`.
Other game instances remain protected by the launcher. The test uses only
127.0.0.1:5121, the owned GodotParty1 module and a fresh external temporary vault.
The installed wizard BIC, user vault and original client are unchanged.

## What the current check proves

`reports/native-shortcut-reconnect-local-v5.json` passes 21 first-session and
15 restored-session shortcut checks, plus the 16 dialogue/examination checks
in each session and two animated/moving native area admissions.

Seven bindings remain assigned while the character is exported, disconnected,
saved again, reloaded from the same vault entry and readmitted:

| Slot index | Page | Binding |
|---|---|---|
| 0 | 1 | Follow command |
| 12 | 2 | Heal skill |
| 28 | 3 | Craft Trap skill |
| 29 | 3 | Parry skill |
| 33 | 3 | Prepared Light spell |
| 34 | 3 | Potion property 0, variant 255 |
| 35 | 3 | Equipped robe, default action |

Native cross-page drag callbacks move Follow and Heal from indices 32/31;
their source slots stay empty in all three actual server-exported QBLists.
Every retained icon loads. The original potion exception is preserved: base49
uses its item icon alone, unlike spell-powered items with two icons.

The potion's runtime ID changes from 2147483666 to 2147483668 after reconnect.
Its saved inventory coordinates (1,4), property and variant still resolve to
the newly replicated owned item. Both sessions consume exactly one potion:
3 to 2, then 2 to 1. The robe re-equips and unequips through four actual server
acknowledgements tagged with their respective connection.

The restored session uses synthetic native viewport Ctrl+F events, with
inventory open, for robe unequip/re-equip, potion, Light and Craft Trap. The
spell consumes one actual prepared use and crafting opens/closes the actual
server conversation. No direct replacement of these requests by client-side
gameplay outcomes is involved. This is authored native input evidence, not a
physical-keyboard acceptance test.

The first session retains weak references to its current shortcut buttons and
textures immediately before export. All are released by the restored session.
The final native exit is zero, disconnect is observed, no commands are rejected,
no native/renderer errors occur and pending inventory icons retire to zero.
The screenshot was reviewed for retained icons/counts; full skin and world
fidelity, clean FPS and complete moving-scene performance are not accepted.

## Server-owned spell readiness

This server readmits the saved character with both Light preparations ready.
The exported BIC records `[0,1]` readiness, and the second preview/upload reads
the exact disconnect-save hash. Nevertheless, the actual incoming player-state
record on connection 3 advertises ready=1 for both Light slots (indices 1/3).
The native shortcut correctly displays those two server-authorized uses, then
consumes one on casting. The same initial two-to-one cast is observed on
connection 1. `shortcutPreparedUpdates` records all four readiness updates.

The test therefore compares native readiness with the received server state,
while separately checking persistent potion quantities and exported spell
records. It does not impose a client-side continuity rule on server-owned
preparation readiness, or claim why the server's admission logic restores it.

## Evidence and retained failures

`tools/shortcut-reconnect-evidence.cjs` requires canonical current inventory,
real per-connection item/cast/skill requests, server conversation and equipment
acknowledgements, all three exported QBLists, matching vault read-back hashes,
incoming preparation records, consumed counts, native presentation and clean
shutdown. A completed UI callback or early engine exit cannot accept the test.

`reports/shortcut-reconnect-node-v2.log` passes 100 backend tests with no failures
or skips, including five new acceptance checks that reject missing sessions,
stale inventory identities, omitted native/server actions, altered exports,
invented uses, missing movement and shutdown leaks. The native dependency-tree
check in `shortcut-reconnect-parse-v2.engine.log` also exits zero without errors.

Retained rejected local attempts: v1 caught a test-script void-return misuse;
v2 incorrectly required a second potion icon; v3 reused a screenshot filename
between sessions; v4 incorrectly required spent spell readiness to persist
against the server's readmission update. V5 corrects those expectations and
adds explicit native F-key input and current-resource retirement checks.

Broader feat/innate/family/custom-command persistence, charged or paired items,
pending assignment/resource work during disconnect, alternate server policies,
forced failure/recovery and physical-device/fidelity review remain. The full
UI → rendering → combat migration and sustained moving-scene 60 FPS goal stay
active. No Arelith or other public server is contacted.
