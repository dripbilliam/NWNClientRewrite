# Native inventory, store and trade item wheels — scoped milestone

The former rectangular native inventory action popup has been replaced by an
original-artwork radial owner, `systems/native_item_context.gd`. It owns item
context lifetimes independently of the world/character wheel, shares its native
radial geometry/artwork, and cancels the other wheel when opened. Native Godot
projects every entry, label, icon, count and family. The JS session remains only
the existing protocol/resource service. Full UI parity is still incomplete.

## Original evidence and action policy

`../backups/animations/rea-native-item-context-v1.json` contains current shipped
binary dossiers for item root1409a59d0, repository/merchant1409a7ee0,
equipment1409a6af0, inventory callbacks882390/8823d0, equipment/use/store
callbacks and split/learn owners. Target SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

`scripts/inspect-native-item-context.py` executes the unchanged three context
owners over2688 cases, capturing lookup, interaction permission and GUI entry
publication boundaries. It proves the scoped entry slots, labels, equipment
slot payloads, ring preference, merchant/container branches and slot-wide
CanUse disabling. For example, native equipment setup can disable existing
actions at slots2/6 as well as the equipment entry it creates. Captured power
population is verified separately, not inferred from this context oracle.

The existing `native-item-radial-observations.json` was produced by
`scripts/inspect-native-item-radial.py`: original71a0 power root,6450 property
page and5fe0 variant creator. `native_data/item_radial.gd` compares directly
against those observations. It preserves first-property tool handling,
slots3/5/7, the two-entry root before More, cast-only page offsets, physical
property indices, remaining-use disabling, charge/daily counts, infinite-use
badges, scroll-learning class flags and original TLK references. Family children
retain their packed high-WORD index even when a child spell is missing or a
negative numeric SubRadSpell cell was successfully loaded. Filtering those
entries first would silently cast or assign a different child.

Root context distinguishes equipped items, carried inventory, owned containers,
loot containers and merchant stock. Cast-on-item uses the active spell tables
and an item-target mask. Merchant right-click is enabled, with original Examine
and Buy entries; carried items can offer Sell while a store is open. Every
selection rechecks the captured repository view, received item/location and
store generation before dispatch. Original-item icon proportions are retained
at the wheel center, with shared original button/icon artwork.

Original inventory callback8823d0 explicitly suppresses the standard item menu
for a barter repository. The user-requested trade item wheel is therefore a
replacement extension: remote offers expose Examine; own offers additionally
expose Remove. It uses native radial styling and revalidates the trade serial,
received item signature, ownership, locks and pending operations. A received
lock/unlock refreshes its action state. No local item membership changes.

## Native action paths

- Examine/equip/unequip/drop/container/store choices use the existing typed
  inventory/store owners. Loot equipment first requests pickup; only received
  backpack ownership permits the follow-up equip request. A pickup reply alone
  is not treated as ownership transfer.
- Item powers and child variants feed the native targeting owner with original
  item/property/variant payloads. Native item-family drag reaches the actual
  quickbar widget with a distinct `item-radial-entry` lifetime; assignment goes
  through the native desktop's canonical shortcut request. Dismissed or stale
  wheels cannot supply bindings.
- Split uses the original `INV_STACKSPLIT` resources and shared amount controls,
  with an item-specific callback and captured repository lifetime. It sends
  original6/23, an object ID and WORD amount. Only received item updates clear
  the split pending state; no local stack or new item is invented.
- Learn sends original12/13. The original14 response acknowledges processing
  even when the server refuses learning, so it is decoded as `inventory-ack`
  without a fabricated success flag. Only a matching controlled-inventory learn
  pending state is released. Alternate or late replies cannot clear unrelated
  actions. Feedback and known-spell/item updates remain authoritative.

`scripts/inspect-native-item-menu-requests.py` executes unchanged7c0050 and
7c0ee0 senders with the original scalar/object-ID writer and message extraction;
30 retained packets are compared by `network-item-menu-requests-native.test.js`.
Transport is captured, never opened. Padding bits remain explicitly masked in
the comparison, as in the existing original writer tests.

## Verification and explicit remaining work

The scoped suite includes native context/power oracle comparisons, real native
viewport item-wheel/merchant/split input, a child-power drag into a quickbar,
stale view/store rejection, alternate/late learning replies and native barter
locked/unlocked item actions. Family artwork is reviewed at1×,1.5× and2×;
these images do not certify every UI scale or the surrounding window geometry.
The item-wheel UI fixture uses local authored snapshots, not invented claims of
server acceptance.

Owned loopback checks additionally exercise actual equipped-wheel Unequip,
native split dialog with server-created item/count conservation, item-wheel
potion consumption, learn refusal acknowledgement and the existing complete
gameplay regression. A separate two-participant test covers offered-item wheel
removal and remote examination. Final acceptance and source/checkpoint hashes
are recorded in `reports/native-item-context-acceptance-v1.json` when verified.

The full UI goal remains active. This milestone does not certify:

- Positive scroll learning for every class/server rule set, every tool/property
  family and item activation case, or every original server refusal/feedback.
- Alternate/associate inventory and possessed-creature restrictions, DM actions,
  all ground-item root paths, quickbar assignment variants and their role rules.
- Original multi-item paired equipment behavior, all nested container equipment
  sequences, and exact item pending/result timing for every message ordering.
- Complete radial tooltip fonts, hover previews, all selection/cancel preference
  modes, icon/count drawing states, amount-edit validation/repeat arithmetic,
  localization and full original-client side-by-side visual comparison.
- General window/HUD/menu/NUI completion. Original-artwork framing and scoped
  passing tests are not proof that the entire UI objective is finished.

No automated public-server connection or manual-client restart is performed.

## Scroll learning and original feedback follow-up

The stock original server is now exercised through the actual native item wheel
for successful learning as well as refusal. The owned `GodotItemUi3` fixture
creates the original `nw_it_sparscr101` (Endure Elements, stack2) and
`nw_it_sparscr102` (Protection from Alignment, stack1) through `CreateItemOnObject`.
It never grants known spells or edits the test character's classes/abilities.
The installed wizard initially knows neither spell. The test observes learning,
stack2→1, duplicate refusal with no consumption, final-scroll destruction, known
spell replication and both native spellbook rows, including the family parent.
It waits for received inventory cells before another interaction and for native
icons before retaining its final viewport. First attempts remain as failed
receipts: v1 had a JSON numeric-type assertion mismatch; v2 clicked against the
previous inventory view before publication. Neither is accepted evidence.

This exposed a presentation omission: the conservative general feedback export
excluded branches with GUI sound side effects. Native `scroll_feedback.gd`
now handles original feedback78–81,219–222 and224. Refusals use their original
TLK references;222 looks up the received spell ID in the active server's spell
table, fills custom token0 and parses TLK53307. Per-message tokens do not alter
stored server tokens. The native gameplay UI forwards the original error or
success sound to the native catalog/WAV/audio owner. Original `PlayGuiSound`
1f6110 specifies a nonpositional one-shot at priority9, delay0/default volume.
No inventory outcome is inferred from either a sound or reply14.

`scripts/inspect-native-scroll-feedback.py` executes144 unchanged original
formatter cases with captured spell-name/TLK/audio/display providers. The
negative-ID/non-null captured-spell combinations probe the formatter's copy
boundary; production correctly treats negative IDs as unavailable table rows.
The native suite also checks actual gameplay-UI chat and sound forwarding and
rejects replay of a preceding message's cues. Retained local audio history
confirms both original WAVs are decoded/played through the native path.

The final scoped acceptance is recorded in
`reports/native-scroll-learning-acceptance-v1.json` when verified. This closes
the positive stock-wizard learning gap from the earlier item-wheel milestone;
it does not prove every learnable class, modified spell table, school/ability/
level refusal, localized TLK, sound preference, role or inventory source.
The broader item and entire-UI gaps listed above remain active.
