# Item-property mutation and effect ownership

Target NWN:EE `89.8193.37-17`; original executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Ghidra/assembly and isolated original instructions remain read-only. No binary
or asset copies, live process alteration, actual transport or Ghidra edits.

## Implemented state and commands

`item_property_mutation.js` decodes AddItemProperty14050fb00..14050fd56 and
RemoveItemProperty14053b4a0..14053b627 after successful typed VM pops. Add
accepts duration1/2 with exact WORD flag masks and temporary FLOAT storage,
admits canonical items, applies the effect, then retains the permanent guard's
original order (setting134, owner/stats/lock/spell419/slot/level/minimum level,
unequip and repository insertion). These later owners remain supplied inputs;
the runtime does not guess an unknown setting or minimum-level calculation.

Remove changes exposure DWORD20 on **every** matching live uint64 effect ID,
then schedules event14 using the last matching pointer. It neither edits a
previously returned VM copy nor deletes the property immediately. Invalid
targets release the popped structure; a valid item without a match has no
event. The existing event14 receiver reaches EffectRuntime removal for items.

Type91 application now uses the shared property pool/materialization admission
and retains accepted effects. Removal calls the decoded OnRemoveItemProperty
1404373c0..14043776b before erasing the owning effect. Temporary expiry uses
the low duration bits and the existing strict-after-deadline update behavior.
Negative/nonfinite temporary lifetimes remain explicit failures.

Pool removal matches the first narrowed property values and duration flag,
not propertyId. Active matching checks chance; passive matching checks uses
per day. Passive matching retains the original last examined property pointer
for its callback even when no match was found. Weight, equipped lookup, AI
callback, pool erasure, combat update, special weight/encumbrance, visual and
price-dirty ordering are preserved. Native removal always returns1 and dirties
price, including temporary/no-match paths; application dirties only permanent
property state. These differences are not normalized away.

The bounded application post-block14042e83e..14042e942 is connected to normal
NativeItemRuntime loading and mutations. The callback receives the original
stack property copy, separate from active-pool counter restoration.

## Equipped effect identity

OnItemPropertyApplied140473790..140473acf snapshots exact effect-pointer
identity, invokes the selected concrete materializer, then annotates only newly
retained effects. Innate duration4 is excluded; duration/creator warnings retain
their native gates. New equipped effects receive the property's distinct
uint64 propertyId. This is independent of canonical object IDs and effect IDs.

OnItemPropertyRemoved140473ad0..140473c2f snapshots effects with the same
propertyId and removes those exact references. It then invokes any registered
custom removal handler. Full assembly exposed this final dispatch beyond the
truncated decompiler output. EffectRuntime.removeOne now accepts an optional
exact reference so duplicate effect IDs do not change this pointer operation.

InitializeItemPropertyArray140473330..140473786 executes to produce both
88-entry tables. `item_property_handlers.js` retains actual nonnull entries,
including custom removal13/61, so native no-ops differ from unfinished handlers.
Concrete equipped materializers are still missing and throw when selected.
They are checked before appending a property, preventing an unsupported buff
from being stranded without its owning effect/expiry. Unsupported permanent
setting134 is also checked before changing a valid target item. These guards
are explicit partial-runtime behavior, not claims of a completed native path.

## Original comparisons and installed check

- 452 complete original command executions cover duration flags, target/cast
  admission, permanent guard ordering and duplicate-ID exposure/event behavior.
- 980 original pool/post executions include532 complete removal owners and448
  bounded application post-blocks, with active/passive mismatches, null records,
  missing owners/AI, equipment, weight and callback order.
- 102 complete apply/remove wrapper executions cover pointer snapshots below/
  above16 entries, reordered arrays, existing versus new effects, duration and
  creator warning gates, property IDs and custom removal dispatch.
- One complete initializer produces both handler tables, compared entry by entry.

VM storage, table/equipment/weight/materializer/event/memory boundaries remain
captured as specified by each producer. This is1,534 command/state/block cases,
not1,534 complete spells or concrete item-property materializers.

`probe-live-item-property-mutation.mjs` uses an ordinary installed session and
plain dagger574 owned by player565. API constructor/add/query/remove succeeds;
the returned copy remains exposed while the live effect hides, event14 removes
the property, exact expiry retains it and the next millisecond removes it.
Canonical ownership persists. A separate installed goblin receives a plain
dagger through normal creation/equip actions to check that missing equipped
enhancement handling rejects the change without property/effect-pool leakage.
The unavailable permanent setting guard is checked similarly. Both expected
direct-API failures are explicitly stored in the report, distinct from errors
in the successful repository-item phase. Ordinary script failures still use
the VM's contextual diagnostics.

Captures in backups/animations: native-item-property-commands-v1,
native-item-property-pool-mutation-v1, native-item-property-effect-linkage-v1,
native-item-property-handler-map-v1 and corresponding JSON files;
live-item-property-mutation-v4.txt/live-item-property-mutation.json. Complete
command, pool/remove, dispatch and initialization assembly is retained.

## Validation and next work

1,430 tests pass; build passes (item-property-mutation-all-tests-v3.txt and
build-v3.txt). Rendered item-property-mutation-transfer-ui-v1 passes radial
summoning/slot use, Follow/Stand, out/back canonical summon575/master565 and
dismissal. Latest screenshot inspected; scene remains dark and autosave remains
visibly diagnosed. Original executable hash rechecked unchanged.

Static audit-v19 now has110 unbound names and the same22 missing scripts.
Add/Remove bindings have supported repository-item paths and diagnosed missing
branches. Their presence is not evidence of complete buff or campaign behavior.

Next implement the concrete materializers and connect native equip/unequip
property traversal. Complete bodies for enhancement14046fee0..14047077d,
damage14046ece0 and ability14046dcd0 are captured in
native-item-property-first-materializers-asm.txt. The existing older equipment
projection is not evidence for these lifecycle owners; avoid double counting
once actual equipped effects are retained. Custom removal13/61, permanent
setting134's real owner, minimum equip level/pricing, weapon-attached visuals
and negative/nonfinite lifetimes remain open. Server-info constructor/INI and
GetServerInfo accessor captures are research only; they did not establish
setting134's default. Do not manufacture a value from their names.

Full spellcasting, combat, receiver/ready, autosave and continuous campaign
acceptance remain unfinished. Formal goal stays active. Verified backup report:
backups/animations/item-property-mutation-checkpoint.txt.
