# Native item powers and shortcut choices

This extends [inventory item shortcuts](NATIVE-INVENTORY.md#inventory-item-shortcuts).
Right-click an owned inventory item, navigate its original power/variant wheel,
and drag a usable leaf onto the native quickbar. Clicking still uses the action;
family parents and More entries still navigate. The menu explains the drag
gesture. This is partial migration work, not full quickbar or combat parity.

## Implementation

`tools/action-service.mjs` reuses `prepareNetworkItemMenu`, `itemUseEntries`,
`itemPropertyPage` and `itemVariantEntries`. Actual active properties, physical
property indices, family variant indices, localized labels and original icons
remain owned by the existing JS rules. The native drag carries only the private
request/menu identities and physical slot. It cannot supply item IDs, property
indices, variants or shortcut contents to the assignment handler.

`tools/spellbook-service.mjs` resolves the canonical leaf, revalidates actor,
menu, item metadata/location and current shortcut contents after asynchronous
rule preparation, then uses the original item configuration and assignment
sender. Only owned I/R items qualify. Disabled entries and parent menus cannot
be assigned; pending writes cannot duplicate. Successful assignment closes its
own wheel without closing a later replacement. Failed writes remain retryable.

The native wheel button now supports Godot drag dispatch. The quickbar accepts
only a current radial leaf and current destination owner. Power icons and
secondary item icons use separate native textures with the same private owner;
late completions cannot decorate replacement bindings. Charge-based powers now
honor the existing count adapter's disabled result, including string `"0"`.

An integration run also exposed an in-flight presentation race: a committed
inventory refresh could retire the view before its displayed item's click
arrived. Inventory entry commands now retain at most eight previous owners,
with complete canonical item identity, membership, location, metadata and
world/context checks. Navigation and icon delivery still require the current
view. Quickbar commands similarly retain at most eight presentation owners
only while all canonical bindings still match; activation checks current uses.
Both caches clear on reset. No transfer, use result or gameplay state is
predicted by these presentation owners.

## Evidence and local acceptance

- `reports/radial-shortcut-node-v5.log`: 58 passing backend cases, zero failures
  or skips. New cases include original family variant and physical property
  selection, More pages, charge disabling, primary/secondary icons, targeted
  item submission, forged binding fields, stale owners, pending writes and
  harmless refreshes overtaking input. Replaced bindings/items/worlds, changed
  membership/metadata, page changes and cache eviction remain rejected.
- `reports/radial-shortcut-ui-v1.json`: 13 passing authored Vulkan GUI checks
  for actual synthetic viewport drag dispatch, private drop data, parent and
  disabled entries, pending/stale menus and secondary icon ownership.
- `reports/radial-shortcut-ui-headless-v2.json`: 14 passing native checks after
  adding the explanatory gesture hint. Its engine log is clean.
- Inventory/spellbook/action native regressions pass 24 / 22 / 8,000 checks in
  `radial-shortcut-{inventory,spellbook,action}-regression-v1.json`, with clean
  logs. Most action checks are the retained original-derived hit-band oracle;
  this count is not 8,000 independent gameplay cases.
- Local runs v3 and v4 prove the real wheel creates the potion binding and its
  activation sends `useItem(propertyIndex=0, variant=255)` through the original
  session. The real server decrements the installed sample's potion stack
  from 3 to 2. The sample remains read-only; the client uses an external
  temporary regression vault.

`reports/native-radial-shortcut-local-v5.json` passes all 26 checks. It records
both configured shortcuts, all four equipment acknowledgements, two clear
operations and potion consumption from 3 to 2. Native exit is 0, disconnect is
explicit, no commands were rejected and no native or renderer errors were
reported. The native inventory/book frame was reviewed. The original NWN
client and editor remained open by explicit user instruction; these functional
results are not a clean performance benchmark.

Retained failed attempts: local v1/v2
looked for backpack contents before subscribing to inventory and therefore
failed their fixture prerequisite. Corrected v3 consumed the potion but failed
the earlier equipment shortcut check with an observed stale inventory owner.
V4 passes that assignment and all four equipment acknowledgements, but fails
the earlier clear control check. The analogous strict quickbar-owner pattern
was corrected and covered by authored tests, then verified in v5. All four
earlier reports retain `success: false`.

The v5 launch was stopped before admission by the existing-game guard because
the original NWN client was running. The user then authorized local functional
tests alongside that preserved original instance. The launcher now accepts
`-PreserveOriginalPid 49160`; the guard exempts only that NWN process and still
rejects other game instances. No Arelith or other
public-server connection was made by the replacement client. The user-deferred
emoji/native-engine investigation remains deferred and production Godot stays
pinned. Existing particle and unhandled game-message diagnostics remain open
and are not accepted by this UI work.

The local gate uses `join-local.ps1 -InventorySmoke -Report <unused>.json`
against the owned GodotParty1 server. Its 26 checks require default and power
assignments, four equipment acknowledgements, exactly one consumed potion,
clearing both test bindings and clean native shutdown/disconnect. The accepted
report additionally confirms no rejected commands.
Broader real family-item/paged-power cases, depleted/denied uses, secondary
weapon icons, reconnect persistence, physical-device review and full assignment
menus remain open. No full gameplay or moving-scene performance acceptance is
claimed.
