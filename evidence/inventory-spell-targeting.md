# Prepared spells targeting inventory and equipment

Target NWN:EE `89.8193.37-17`, executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original executable/install and Ghidra database remain unchanged. Research uses
read-only static analysis and isolated original instructions. No proprietary
binary or resource assets were copied into the workspace.

## Item target UI and original evidence

The replacement previously canceled spell targeting when inventory opened, and
item buttons always opened Examine. `GameUi.inventoryItemButton` now routes a
pending spell selection to the clicked canonical inventory/equipment item.
Opening inventory preserves that selection. Ordinary item clicks still examine;
right-click cancels a pending selection or opens the item wheel. Selection and
wheel actions re-resolve current possession, inventory membership, player/session
and area before submitting through the existing player spell-input queue.
Spellbook, F-key hotbar and item wheel use the same resources and action owners.
Canceling explicitly clears the cursor and replaces the old targeting notice.

CGuiItemMenu RTTI descriptor `1412dc2c8` resolves vtable `140e761d8`, whose
constructors are `1409a5940/1409a5990`. Item spell creator
`1409a5f10..1409a5fd7` accepts branch1, resolves its saved item ID at+7f8 through
`1406abc80`, copies client item position+80/+88 and constructs the ordinary
spell menu at `1409a5fa9`. It sets byte7f1=1 and target filter WORD898=8. The
replacement supplies that item-only filter to the shared class/metamagic/level
builder and uses the existing native-checked target-mask and packed-selection
rules. World target clicks now reuse the same mask helper, including trigger64.

The constructor's fifth argument1 enables building entries; it does **not**
force a grouped class menu. Full constructor `1409a10e0..1409a199d` checks class
count and configuration `ui.radial.spellcasting.always-show-as-subradial` at
`1409a13aa..1409a145e` (lookup default0). The item menu keeps that ordinary
grouping. An initial forced-group implementation was corrected before the final
rendered test. Captures: `native-item-spell-menu-creator-asm.txt` and
`ghidra-item-menu-spell-creator.txt`.

The cast-message caller `140998880` was investigated as a candidate but belongs
to the creature spontaneous-casting menu: verified caller `140992920` contains
CGuiCreatureMenu source warnings. Its candidate filenames are not evidence of
inventory ownership. Common targeting-mode selection `140868e70..140869389`
was also located; it handles readiness, conversion, DM state, icon and UI
ownership. Its decompilation truncates at cleanup and those complete owners are
not claimed implemented here. Exact native inventory widget event handling is
not independently emulated by this UI change.

## Light effect failure found through the log

The first rendered test established target/queue acceptance and slot consumption.
Adding inspection of all runtime diagnostics exposed a real AddItemProperty
failure: the installed Light NCS reached unimplemented property44 on equipped
clothing. That failure was fixed before final acceptance; queue/slot checks alone
were insufficient evidence of an applied effect.

`materializeLight` implements full ApplyLight `140472270..1404723c6`:
HasProperty44 gate, Param1Value BYTE color selection and CostValue WORD intensity
1..4. Color bases are153,157,161,165,177,169,173, followed by intensity-1. It
creates type54/duration3, binds the item creator and applies to the equipped
owner. The native handler passes loading to both lower ApplyEffect integer
flags. Ordinary flag0 is connected; a nonzero fourth flag remains an explicit
failure pending the complete generic ApplyEffect owner, rather than being
silently discarded.

OnApplyLight `14042ed70..14042ee1f` now creates a hidden type30 child on creatures
using the real copy-constructor profile, writes integer0 from the light parent
and applies it with the loading argument. The native copy constructor preserves
ID/metadata but resets type/exposure/icon/INT data. `EffectRuntime.copyConstruct`
shares that profile with item materializers; the older controller-copy adapter
remains separate. OnRemoveLight `140437810..140437816` is the verified return1
leaf; outer property-ID/ID removal owns the copied visual and looping entry.

`native-item-light-observations.json` records378 complete unchanged materializer
executions and18 complete OnApplyLight executions using actual native effect
constructors/copy constructors. Table/property, creator, virtual creature and
lower application calls are captured boundaries. Tests compare their payloads
and observable callback order; the JS direct integer read is not instrumented as
a separate provider. These comparisons do not prove complete generic effect
bookkeeping or visual rendering.

## Live and rendered validation

- `live-equipped-item-buffs.json` / `live-equipped-item-buffs-v3.txt`: queued gear
  actions on installed dagger/NPC. Light visual179 creates parent54 and hidden
  child30 with shared IDs/property links, one looping entry, correct unequip/
  re-equip and strict expiry cleanup. Other enhancement/ability/damage cases
  continue passing. All diagnostics, including light presentation omissions,
  remain in the report.
- `live-casting-item-545.json` / `live-prepared-item-casting-v2.txt`: ordinary
  installed wizard prepared Greater Magic Weapon consumes uses1→0, plays
  conjure15/release18, executes installed X2_S0_GrMagWeap and adds property6cost5
  to carried item573 owned by canonical player565. This uses player input,
  without cheat casting or manufactured spell slots.
- `live-item-targeting-ui.json` / `item-targeting-ui-v4.txt`: rendered spellbook
  Light targets equipped robe566; real F2 Greater Magic Weapon targets carried
  dagger573; item right-click wheel casts Light immediately on that dagger.
  Two Light slots and one Greater Magic Weapon slot are consumed. Right-click
  cancellation leaves inventory available with clear feedback. Browser errors
  and engine-call failures are empty. All runtime diagnostics and log path are
  saved, rather than filtering out background failures.
- `item-targeting-self-ui-regression-v1.txt`: existing self spellbook/radial
  casts, slot use, casting animations, defensive casting, counterspell target22
  and hotbar/Escape/right-click cancellation still pass.

1,438 tests and production build pass. Final inventory and cantrip-wheel
screenshots were visually inspected. The scene remains dark: looping light
rendering is unfinished and recorded as `effects.light-presentation-unimplemented`.
The rendered log also retains DM preset import rejection, missing plc_w02
type2053, model/animation omissions, AI and other existing diagnostic records.
No engine-call failure is not a claim that the campaign runs without issues.

## Remaining work

15 of52 concrete item materializer types are connected;37 remain. Looping spell/
light presentation, model light nodes, complete ApplyEffect loading/bookkeeping,
custom property removal13/61, permanent ILR/pricing, full client targeting mode,
epic/placeable/item-charge casting and other spell owners remain unfinished.
The UI tests use installed presets and an in-memory entry-position/startup
fixture. They do not prove continuous campaign progress, exact native UI art or
every targeting/casting branch. The formal spell→combat→campaign goal remains
active, with completion unproven.
