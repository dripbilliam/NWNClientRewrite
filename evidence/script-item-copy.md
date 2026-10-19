# Public item copying and shared acquisition

The preceding creature corpse turn made concrete progress and sealed
`backups/creature-corpses-20261017-v1.zip`. This increment continues the full
ACTIVE single-player spell/combat/campaign objective; it does not establish
complete spell, combat, multiplayer or campaign acceptance.

Read-only original target: NWN:EE89.8193.37-17 x64,
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No original installation or Ghidra project changes. Read-only REA dossiers and
original-code observations are retained under `backups/animations/`.

## Complete wrapper and lower acquisition owners

`script_item_copy.js` ports ExecuteCommandCopyItem `140512600..1405128e5`.
Mandatory source and optional target/variable arguments retain their original
typed-pop order. Decoder failure returns native-639; result-push failure is-638.
The VM binding584 returns the separately pushed OBJECT_ID, not the status.
An invalid source allocates nothing. A rejected CopyItem destroys its newly
constructed destination. Success clears the copied possessor via SetPossessor
with native0/0/0 flags before attempting placement.

Omitted/INVALID targets first inherit the source's direct possessor. An
unpossessed source instead supplies its native area and XYZ point. Explicit or
resolved targets run original world/creature/placeable/item/store cast order,
including repeated casts. Acquisition uses native arguments, particularly
creature allow-drop0. A failed acquisition falls back to the target's own world
area and point; it does not resolve a held item's owner position. Missing or
nonworld explicit targets leave a registered unplaced copy. Mutable acquisition
pointers determine the returned ID after stack merging or gold conversion.

The previous increment's complete selective CNWSItem::CopyItem supplies the
actual copy, preserving canonical object identity rules and allocating fresh
effect IDs. The public wrapper does not clone a UTI record or implement named
spell results. Active scripts can call the same shared command.

`acquireContainerItem` ports complete CNWSItem::AcquireItem
`140463e80..1404640d8`. Any repository on the incoming item rejects it, including
an empty one. Native source/parent possessor gates, optional position finding,
fit, previous-owner removal, nested-container rule checks, mutable repository
addition, area removal and possession writes retain order and flags. Source
repository membership, direct possessor and canonical object lifetime remain
separate owners.

`acquireStoreItem` ports complete CNWSStore::AcquireItem
`1404f9ea0..1404fa049`: plot rejection, identification, direct creature or
item-parent resolution, owner removal, active store panel, tag lookup, infinite
stock comparison/disposal and sorted repository insertion. Its pointer argument
is by value. Infinite-stock disposal can destroy the copy while the public
wrapper still returns its ID; the adapter deliberately does not manufacture a
replacement ID or clear the caller's pointer.

`appropriateStorePanel` ports complete GetAppropriateListId
`1404fb590..1404fb5fd`: active base-row StorePanel BYTE, warning/default4 for
unknown panels, diagnosed invalid-base fault domain. The existing independently
verified AddItemToInventory handles sorting, price and physical repository nodes.

`repositoryFindTag` ports complete recursive FindItemWithTag
`1404680a0..1404681cd`. It normalizes the requested tag with the native AsTAG
owner, checks each physical node before visiting that item's child repository,
honors object-array lookup status, and preserves explicit string-length plus
strcmp semantics. A malformed non-item node or recursive cycle is diagnosed,
not treated as successful lookup.

Runtime providers connect actual repositories, canonical lookup, active base
rules, native prices, stack comparison, SetPossessor, area insertion, removal
and destructors. `CreateItemOnObject` also reuses the now-available native
container/store acquisition paths; its previously verified distinct wrapper
arguments and ignored acquisition BOOL are unchanged.

The creature animation adapter previously read weapon base-item values from an
authored UTI record. Native copies intentionally have no such record. Weapon
class, special base111 size handling and preferred attack distance now read live
canonical baseItem for loaded items. A regression exercises empty/stale authored
data without introducing a cloned template. Semantic old fixtures retain their
explicit authored fallback; loaded native items do not guess missing live data.

## Validation and its scope

`inspect-native-script-item-copy.py` executes COMPLETE original owners with
captured lower allocation/copy, lookup/cast, repository, identification,
possession/removal and store helpers. **1138 cases PASS**:283 wrapper,
656 container and199 store. Optional counts, signed/full-width IDs, decoder/push
failures, missing targets, repeated casts, source chains, pointer replacement,
null pointer, fits/rejections, arbitrary nonzero results, infinite disposal and
fallback call arguments are covered. A null mutable pointer passed into a
captured AddToArea verifies the wrapper's unguarded call; it is not evidence
that the original lower method safely accepts null. Real lower fault domains
remain errors in the client.

`inspect-native-repository-tag.py` executes complete lookup recursion and panel
selection:344 tag cases plus9 panel cases PASS. Captured boundaries are AsTAG,
linked-list node access/advance, object-array lookup/item cast, string release
and base-row/logging. Native length checks, strcmp, recursion, ordering and
panel clamping execute original instructions. Native AsTAG itself was separately
verified in earlier work. Total **1491 new original-code cases PASS**.

Initial native capture failures are retained: the copy oracle first lacked the
synthetic rules global for a nested-owner branch; the tag oracle initially used
the wrong C++ hidden-return ABI for AsTAG. Assembly at1404680c8..1404680d0
establishes RCX=this/RDX=result. The fixture was corrected rather than changing
production behavior to fit invalid observations. Final native-v2 logs and
`script-copy-focused-v3.txt` pass. All18 focused tests passed; after completion,
the single shared-system checkpoint suite passed **1990/1990**. Full suites were
not repeated for each small edit. Production build passed with the existing
chunk-size warning (`script-copy-build-v1.txt`).

`installed-script-copy-item-v1.json`: **15 scenarios PASS** using actual installed
Prelude, cleric, UTI/UTM resources, active rules and real VM CopyItem calls.
Checks invalid/non-item sources, omitted/stale/explicit targets, copied variables
and full effects with fresh IDs, creature/placeable/container/store acquisition,
ground/fallback placement, populated/empty container rejection, store plot and
infinite-stock behavior, stack pointer replacement and CreateItemOnObject's
shared adapters. Source objects, PC identity and repository ownership remain
canonical. General AI/startup are isolated; fixture locals/plot and store
infinite state are explicitly controlled. No save/render/campaign claim.
The retained diagnostic is `items.merge-client-message-unimplemented`:
simulation stack merging is verified, its destroy-item client feedback remains
unimplemented. Load/error diagnostics for this probe are empty.

Installed world-ownership and seven-path creature-corpse regressions also PASS
(`installed-script-copy-world-ownership-v1.json`,
`installed-script-copy-corpses-v1.json`). Existing bundled casting UI regression
PASS: spellbook click, radial self cast, slot consumption, hotbar F2 targeting,
cast clips/cancellation and counterspell world radial mode/target
(`script-copy-casting-ui-v1.txt`, terminal0). After the final narrow animation
accessor fix,15 focused animation/copy/lookup tests PASS, including one new
regression. The full1990 suite/UI preceded that final fix; they were not rerun
for that small edit. The final build is checked separately below.
Final production build `script-copy-build-v2.txt` PASS after the animation fix;
the existing chunk-size warning remains.

Active spell auditv55:840 rows,596 loaded impact scripts,**52 unbound commands**
(previously53),22 load failures. CopyItem584 is used by four active scripts,
including dye/ruin-armor families. Their other commands are still missing:
binding this call alone does not prove those spell paths are complete. The
audit's exit1 is expected and retained; it is not a green campaign gate.

## Remaining work

Full spell effects/interaction, combat, inventory/pickup presentation and
save/autosave/campaign acceptance remain open. Existing per-part palette
rendering and structured JSON/Cassowary variable-copy gaps remain diagnosed.
Door/trigger death-XP creator adapters, ordinary dying and associate death
owners are separate unfinished work. No module-specific outcomes were added.

Verified checkpoint `backups/script-item-copy-1990-20261017-v1.zip`:
10924 files,157461735 bytes, every archived length/SHA256 verified.
`script-item-copy-checkpoint-v1.txt`, terminal exit0. This note was added after
sealing; all validation handles are terminal/consumed. Goal remains ACTIVE.
