# Store templates, stock and item pricing — 2026-10-16

Target: NWN:EE89.8193.37-17 x64, unmodified `nwmain.exe` SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original game assets remain read-only. No Ghidra database edits.

## Complete original owners and comparisons

`src/store_template.js` ports Store::LoadFromGff1404fbbf0..1404fc749.
`inspect-native-store-template.py` executes that complete body for291 synthetic
cases; `store-template-native.test.js` compares fields and full lower-call order.
Typed GFF, string/tag/localized operations, array allocation/lifetime, item
construction/loading/base-info/pricing/acquisition/possession, UUID and module
tag insertion remain explicit lower boundaries in this caller comparison.

The loader imports LocName360; BlackMarket378, BM_MarkDown37c, MarkDown380,
MarkUp384, StoreGold38c, IdentifyPrice390 and MaxBuyPrice394. WillNotBuy398
and WillOnlyBuy3a8 append valid nonnegative typed INT base-item IDs without
clearing retained arrays; a nonempty WillNotBuy list suppresses WillOnlyBuy
appends. Scripts308/318 are resrefs copied into strings; data ResRef overwrites
base template30, then the outer template wrapper overwrites it with the requested
resource. This owner adds its module tag **before** UUID loading. Unlike the UTP
owner, it does not call the five common visual-data loaders.

StoreList's outer status and inventory-element statuses are ignored by the
native caller. ItemList presence uses nonzero status. The provider owns output
handle semantics; typed parsed list elements are always valid records in the
concrete bridge. Saved ObjectId is read only for loading!=0. Any existing raw
canonical object skips allocation, confirmed by guard thunk14055b4c0 ->
14055fca0..14055fcd2 -> GameObjectArray296470 (no item-only cast).
New item-load success must be **exactly1**. Failed loads destroy the new item.
Successful stock reads Infinite444, forces identified, and uses base-info
StorePanelSort34 and StorePanel33. Invalid panels warn and use4. Temporary lists
sort descending by priority and unsigned price, then acquire in reverse order
for panels0..4. The original final SetPossessor guard is retained: R15 is the
last allocation pointer, even after destruction; a final skipped existing ID or
allocation failure suppresses possession calls for previously loaded stock.
Tests explicitly retain that unusual behavior instead of repairing it by guess.

`src/store_item_acquisition.js` ports AddItemToInventory1404fa1b0..1404fa53f.
116 original runs compare tail-to-head GetPrev traversal, stale/duplicate IDs,
suffix removal and reinsertion, ref mutation, warning/return ordering and ignored
coordinates. Lookup, base-info, pricing, repository AddItem and list operations
are lower boundaries. `140169180` is **GetPrev**, not GetNext; the linked list's
0/8 members are head/tail. Every repository addition uses255,255,0,0 regardless
of supplied coordinates. Add results are ignored by this owner, which returns1
unless its duplicate-ID assertion path still matches after warning.

`src/item_price.js` ports three full item owners, compared against1439 original
executions by `inspect-native-item-price.py` and `item-price-native.test.js`:

* Property cost1404656c0..1404659dd: durationBYTE1 returns0. Query active
  itempropdef Cost, otherwise SubTypeResRef and the subtype Cost; CostTableResRef
  selects the cost table using its native BYTE cache index. FLOAT outputs are
  written even on read failure. A missing selected cost table still multiplies
  by the retained previous FLOAT scratch value. No identity-factor fallback.
* ComputeCost140464e10..140465309: Category4 uses armor Cost and cached item
  base armor35c; other categories use BaseCost. Baseitems ItemMultiplier28
  scales caches. Passive properties and permanent active properties contribute
  according to the actual owner, with special type15 costs read from active
  iprp_spells and cost-table3 physical Cost columns. Charge-cost values2..6 use
  MAX_CHARGES_FOR_ITEM_COST, default50 and signed clamp1..250. Record maxima and
  sums follow native order (old record maxima are not automatically promoted
  to second place). Original FLOAT constants are1,.5,.25,1000, captured directly
  from their verified RIP references. Every SSE arithmetic step rounds to FLOAT;
  CVTTSS2SI uses signed64 destination, then low DWORD storage and unsigned math.
* GetCost140468710..1404687fd: plot==1 and base IDs69..73 return0 unless
  overridden. Dirty cache is recomputed and cleared by this owner. Identification,
  additional cost, ILRStackSize38, stacking thresholds, wrap and minimum1 are
  preserved, including genuine zero-return branches.

`GetGoldPieceValue` is now bound. Original wrapper140525160..140525213 calls
GetCost(1,0,0,0) after raw successful lookup and two virtual item casts, then
pushes a signed INT. `inspect-native-item-gold-query.py` compares32 original
successful VM-pop/push cases, including low-BYTE status and signed output bits.
VM stack error handling is an explicit boundary, not reimplemented here.

Static captures in `backups/animations`:
`store-template-loader-asm-v1.txt`, `store-item-lower-asm-v1.txt`,
`store-repository-iteration-asm-v1.txt`, `store-template-lifetime-asm-v1.txt`,
`store-existing-id-head-v1.txt`, `store-existing-id-owner-v1.txt`,
`item-price-recalculation-asm-v1.txt`, `item-property-price-asm-v1.txt`,
`item-price-constants-v1.txt`, `item-price-vm-wrapper-asm-v1.txt`.
No native OOM/unwinding, STL allocation implementation or arbitrary invalid
native pointer behavior is claimed by these boundary-based comparisons.

## Concrete runtime and validation

Rule-key correction: the original caller passes suffix AX_ with prehashed M.
The earlier AX_ full-label interpretation was wrong. The pricing oracle now
executes the native hash continuation and asserts the complete MAX_ key; all42
templates were rechecked. See [effective-key evidence](creature-template-readiness.md).

`StoreRuntime` is connected through `WorldTemplateRuntime` for UTM resources.
It uses typed GFF reads, active item/price tables, canonical requested-ID
registration, all five native store repositories, exact item identification,
existing repository fit/add and possession owners, tag/UUID and outer locals.
Store ctor buy arrays are included in the existing408-case original ownership
oracle. Destructor cleanup follows1404f9da3..1404f9e1d: reverse buy arrays,
localized name, clients, reverse scripts, before the common base owner.

NativeItemRuntime now retains constructor price/infinite/base-armor cells,
imports typed Cost/AddCost (signed-positive AddCost clamp), computes base armor
through the existing mapped owner, and exposes active-table price providers.
Baseitems Category/BaseCost/ItemMultiplier/StorePanel/StorePanelSort/ILRStackSize
offsets are confirmed in `scheduler-baseitems-loader-asm.txt`. The existing
independently compared FLOAT/table readers provide named and physical lookups.

`store-runtime.test.js` covers concrete typed UTM/defaults/scripts/locals/UUID,
five-panel stock ordering, price caches, saved-ID guard, the original final
allocation possession condition, recursive cleanup, active subtype/cost/spell
tables and charge-rule replacement. It checks bound script gold queries for
identified/unidentified stacks, invalid objects and non-item objects.

`probe-installed-store-templates.mjs` v2 passes for **all42 installed UTM
templates and4,597 direct stock items**. It imports real resources, computes
prices using active tables, verifies canonical panel/possessor/identification,
and recursively destroys stock while retaining allocator cursors. No new error
diagnostics. Startup/AI are disabled. Reports contain derived observations,
not copied game binaries, scripts or assets. This is runtime integration evidence,
not an independent native comparison of all4,597 final prices.

All1,741 tests and production build pass. Installed UTP, UTW and ownership
regressions pass; rendered spellbook/radial/hotbar/counterspell/cast-animation
and radial/body-bag regressions pass, with all owned processes terminal.
The existing large-bundle build warning remains. Logs use `store-runtime-*`.
Checkpoint target: `backups/store-runtime-1741-20261016-v1.zip`, verified by
`backups/animations/store-runtime-checkpoint-v1.txt`.

Remaining limits: this does not implement the store GUI/trade pipeline or replace
the legacy GIT store-import adapter. Engine243 CreateObject remains unbound;
the newly completed UTM adapter is one of its dependencies. Saved effects/actions,
CopyItem, broad visual presentation and campaign parity remain incomplete.
The refreshed static spell audit scans840 spell rows/618 impact names:596 NCS
loads,22 failures,84 unbound command names. GetGoldPieceValue is bound. Presence
is not branch coverage or live-casting proof; all failures remain recorded in
`store-runtime-spell-audit-v1.json`.
