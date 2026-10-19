# Native item appearance modification and encumbrance recovery

Previous goal turn made verified progress on script skill/item-AC queries and
sealed `backups/script-checks-20261017-v1.zip`. This continues the full ACTIVE
single-player spell/combat/campaign objective. None of those broad acceptance
gates is complete.

Read-only target: NWN:EE89.8193.37-17 x64,
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No original installation or Ghidra project changes. Native REA dossiers,
original-code observations and validation logs remain under `backups/animations/`.

## Complete native item modification

`scriptCopyItemAndModify` ports ExecuteCommandCopyItemAndModify
`1405128f0..1405134a6`, command731. Four mandatory typed arguments and optional
copy-variable BOOL retain native pop/status behavior. Invalid source or type>4
does not allocate; negative types preserve the original unchanged-copy path.
The independently verified selective item-copy owner supplies fresh canonical
identity and copied state, rather than cloning a UTI record.

`modifyCopiedItemAppearance` ports the appearance branch
`140512a79..140513295`: simple models, compound model/color components, armor
parts and global/per-part palettes. Signed comparisons and BYTE/WORD narrowing
are preserved, including negative/wrapped indices, sentinel255, warning-only
requests that retain an unchanged copy, and validation failures that destroy
the fresh copy. Category5/type3 and category4/base80/model1 special branches
match original PLT validation. Compound models check both MDL and icon, retaining
the native fixed base-ID set using default ground models. Armor-part edits use
active physical parts tables, then recompute cached AC and unit weight.

`baseItemReference` ports complete GetIconResRef `14029dc80..14029dd31` and
GetModelResRef `14029dd90..14029de41`. Native hidden-result ABI, SHORT model
formatting, uppercase B/M/T components, gender-specific naming and16-byte
CResRef truncation are preserved. Native ItemClass/GenderSpecific/DefaultIcon/
DefaultModel field mappings were checked against the base-item loader at
14029e50e..14029e95a. A malformed compound component reading outside the native
three-byte table is diagnosed rather than assigned an invented name.

Resource validation queries the active module/HAK/KEY catalog without decoding
an asset. CExoResMan::Exists `14018f590..14018f62c` likewise resolves through key entries;
zero-length registered resources still exist. Existing resolver scope applies:
this does not add the original manager's global GetOverride alias facility or
unconfigured loose override sources. Failed existence probes are expected
validation branches, not fabricated successful asset loads.

Placement shares the verified CopyItem acquisition owners. CopyItemAndModify
inherits the source's direct possessor and uses creature feedback0; CopyItem's
explicit/default target route keeps feedback1. Ground XYZ/area, repeated casts,
acquisition mutation/failure fallback, store by-value semantics and the original
unguarded null-result fault domain remain distinct. No extra visual refresh or
price-copy behavior was invented after the appearance write.

## Encumbrance issue found during installed testing

Accumulating copied armor exposed the real missing movement transition at
UpdateEncumbranceState `1403db400`. The previous diagnostic guessed the method
name as ComputeMovementRate. Native analysis establishes the actual complete
owner, **ComputeModifiedMovementRate `1403889b0..140388d1f`**.

`modified_movement.js` now follows its repeated feat240 queries, raw mode flags
and active MOVEMENT_STAGE_PENALTY_* rules. It removes only the original internal
type59/type29 effects, restarts sorted range traversal after every ID removal,
constructs type59[1]/internal duration4 and, for later stages, a matching speed
penalty. The clearing copy constructor preserves their shared effect ID. Speed
is halved with integer truncation for each extra stage; application order is29
then59. Existing native effect removal, immunity, speed-factor, icon and clamping
owners provide the lower side effects. Sorted canonical arrays provide the same
type-range view as native cached indices; no new object/effect identities are
invented by that view.

The actual dye re-equip then exposed another stale authored-record lookup:
GetWeight's runtime adapter used authored.StackSize on a copied item whose
authored record is intentionally empty. Loaded native items now use the live
stackSize cell. A focused regression covers empty/stale authored data and a
changing live stack. Existing semantic fixtures retain their authored fallback.

## Independent comparisons and installed checks

* `inspect-native-item-appearance-modify.py`: **1742 original-code cases PASS**,
  comprising878 complete wrapper cases and864 complete resource-reference
  cases. Original validation, switches, narrowing, field writes, reference
  selection and placement execute. Lower item-copy/ownership, catalog, AC/weight,
  CRT formatting, CResRef assignment and logging are explicit captured boundaries.
  Original per-part palette setter executes as well.
* `inspect-native-modified-movement.py`: **211 complete original-owner cases
  PASS**. Includes changing repeated feat results, all modes/encumbrance states,
  custom/negative rules, internal effect ownership/duration predicates, shared-ID
  removal/restarts and exact construction/application order. Lower constructors,
  effect/feat/rules callbacks are captured; apply/remove update the synthetic
  sorted array and native cached range fields. Native copy semantics were
  independently verified earlier. Total **1953 new original-code cases PASS**.
* `installed-item-appearance-modify-v4.json`: **16 checks PASS** against installed
  cleric, baseitems/parts tables, resource catalogs and real VM731 calls. Six
  global channels, per-part/sentinel/wrapped cases, compound model/color,
  missing-resource destruction, armor/weight, native failures and ground/PC
  placement preserve source objects. Real acquisition reaches overloaded state2,
  weight3892 and factor0.5; public DestroyObject cleanup returns weight472/state0
  and removes the owned stage effects without stale repository IDs.
* Actual installed dye UTI properties select all six active spell rows648..653.
  The untouched dye NCS creates its real work container, copies/recolors items,
  destroys old versions, runs deferred situations and queues native re-equipping.
  **18 paths PASS**: six choices each for armor, helmets and cloaks. Final reports
  are `installed-dye-chest-*-v5.json`, `installed-dye-head-*-v5.json` and
  `installed-dye-cloak-*-v6.json`. Each completes re-equip in one player native
  frame. Fixture targets use installed UTI, native constants and eligibility;
  no outcome JS or work-container bypass is added. General startup/other AI is
  isolated. This is impact/deferred/action integration, not a complete item-use
  cast/resource-consumption or rendered dye comparison.
* Fifteen prior public-copy scenarios PASS. Full shared-system checkpoint suite
  **1997/1997 PASS** before the final narrow live-stack fix. After that fix,
  **17 focused tests PASS**, including a new stack regression; the full suite
  was not repeated for that small edit. Final production build-v2 PASS with the
  existing chunk-size warning. Rendered casting regression PASS: book/radial/
  slot/hotbar/target/cast-clip/cancellation/counterspell (`item-modify-casting-ui-v1.txt`,
  terminal0). GPU shutdown text is retained. No new rendered dye acceptance claim.

The item modification probe retains explicit per-part-rendering and attached
weapon-visual omissions, plus native validation warnings from deliberate invalid
requests. Chest dye player frames retain the pre-existing trap-check warning;
final helmet/cloak paths have no new warnings/errors. Active auditv57 remains
**49 unbound commands /22 script-load failures**, exit1 intentional.

## Retained failures and limits

The first oracle's security-cookie capture clobbered RAX after a resource-reference
helper; preserving that helper's actual return fixed the fixture. The initial
resource helper used lowercase component letters; original comparisons established
uppercase BMT and corrected production formatting. Initial installed failures
exposed the real encumbrance and copied-item weight adapters, both fixed above.

Target-fixture expansion initially confused script slot indices with native masks
and guessed the wrong helmet base ID. It now reads installed nwscript constants.
The first selected cloak was genuinely class-restricted; candidate selection now
uses native eligibility instead of forcing it onto the cleric. Rejected held
candidates must go through public DestroyObject, not raw destructor-only cleanup;
the latter left stale repository nodes and legitimately triggered native weight
warnings. Final fixtures use the public event path and assert all IDs remain valid.
All failed logs/reports are retained. No engine behavior was changed to permit
an invalid fixture item or suppress those warnings.

Per-part palette presentation, attached weapon visuals, type9 skill GUI/logs,
other spell calls/effects, inventory/save/autosave, death/combat and full campaign
acceptance remain open. WriteTimestampedLogEntry560 is now mapped through the
original command table to ExecuteCommandPrintLogEntry `1405397b0..140539a61`;
its complete dossier is saved, but it remains unbound. Normal tested dye paths
do not invoke it. Next work needs native timestamp, log/debug-mode/config and
player debug delivery semantics, rather than a guessed procedure name.

Verified checkpoint `backups/item-appearance-1997-20261017-v1.zip` contains11075
files,159465966 bytes. Every archived length/SHA256 verified; checkpoint log
`item-appearance-checkpoint-v1.txt`, terminal exit0. This note was added after
sealing. Goal remains ACTIVE; all validation handles are terminal/consumed.
