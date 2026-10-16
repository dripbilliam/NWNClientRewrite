# Full placeable template runtime — 2026-10-16

Target: NWN:EE89.8193.37-17, x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install remains read-only. No Ghidra database modifications.

`WorldTemplateRuntime` now admits canonical placeables as well as waypoints.
The previously compared complete LoadPlaceable1404b4900..1404b6702 owner
(431 original executions) has concrete providers for typed fields, localized
storage, scripts, active placeables/traps/portraits tables, canonical item
allocation/acquisition, five visual-data owners, UUID, module tag insertion,
and the outer wrapper's subsequent variable loading. See
[loader evidence](placeable-template-loading.md) and
[wrapper evidence](world-object-template-loading.md).

## Original-code checks and resulting state

* Constructor1404af9c0..1404afd6a initializes TrapType255, Recoverable1,
  Active1, trap faction0, GroundPile0 and BodyBag0. The existing 408-case
  world ownership oracle now captures these defaults too; its base constructor
  remains an explicit boundary. Full static capture is
  `placeable-runtime-ctor-v1.txt` in `backups/animations`.
* Faction resolution14055fb00..14055fc3a reads placeable **350**. The use-object
  executor reads **3d8** for trap faction. Runtime and body-bag primitive views
  now keep these separate. LootCreature510 shares the body-bag source cell;
  the constructor's invalid value and later assignments have one live view.
* Explicit requested IDs use the already compared `addObjectAtPos` owner.
  Normal construction uses INVALID and retains static-load override5a4=1;
  explicit construction uses0. Collisions throw without assigning another ID.
  Saved inventory IDs propagate through nested container loads when loading is
  nonzero. Loading zero ignores serialized ObjectId fields.
* Base HP is E4 and current HP is E0. Normal UTP Fort/Will are separate BYTEs;
  body-bag WORD writes update both. Loaded script members and runtime callbacks
  share cells, including the case-sensitive default trap-script substitution.
* Placeable destructor1404afd70..1404aff40 releases portal, trap-known IDs,
  reverse script array, key strings, description override, localized description,
  display name and localized name, before the previously implemented base
  destructor. Concrete owned strings/localized storage now follow that cleanup.

## Item wrapper and portraits

`scripts/inspect-native-item-gff-wrapper.py` executes original
Item::LoadFromGff14046a9d0..14046ac03 unchanged for **387 cases**. Typed readers,
resref operations, lower template/data/saved-state owners, tag insertion and
visual selection are captured boundaries. Observations compare call order,
full return bits, flag cells and raw BYTE versus BOOL handling. This harness
does not prove the lower item data loader's complete field semantics.

`src/item_gff_load.js` matches those observations. EquippedRes typed presence
wins, including an empty ref; InventoryRes is tried only after failed presence.
Equipped overrides use raw BYTEs; inventory overrides use BYTE-as-BOOL.
Overrides run even after template failure. Embedded loads alone run saved-state,
unconditional tag insertion and visual selection after successful lower data.
The concrete native item runtime and creature/placeable/container import paths
now use this wrapper. Item data also imports all five base visual owners and
UUID at the actual lower-loader call sites14046a727..14046a77a.

Static lower-loader capture `placeable-runtime-item-data-v1.txt` confirms
BaseItem INT/default existing, Tag string/default existing with SetTag,
TemplateResRef resref/default empty (overwriting the requested template), and
loading-flag propagation into nested container loading. Tests previously
expecting the requested template to survive a missing serialized TemplateResRef
were corrected against these instructions. Saved effects belong to4974b0,
rather than the template's lower item data loader.

`scripts/inspect-native-object-portrait.py` executes original numeric setter
14049b930..14049bb40 and ref thunk1404233a0 for **168 cases**. Allocation,
table lookup, concatenation and CResRef construction/copy are lower boundaries;
CResRef normalization is independently compared elsewhere. Numeric IDs below
65534 query active portraits/BaseResRef, prepend `po_`, copy the ref, then store
the original WORD ID. Larger IDs clear the ref. A direct ref assignment retains
the numeric ID. Runtime helpers match, including ignored table status and
NUL/16-byte ref behavior.

## Runtime validation and limits

`test/world-template-runtime.test.js` exercises concrete UTP fields, ctor
defaults, typed wrong fields, script aliases, portrait reload, locals, tag
lookup, independent factions, canonical saved IDs, nested load flags,
failed-item cleanup, reload preserving the repository and recursive destruction.

`probe-installed-placeable-templates.mjs` passes against Prelude and installed
assets: five actual UTPs create IDs574..578, insert/move between areas1/37 with
real geometry, then release spatial/area/registry ownership. A RAM-only UTP
fixture loads installed `x3_harathide` via both embedded and template-reference
paths; reload appends IDs582/583 while retaining580/581, and destruction frees
all children and UUID without rewinding the allocator. No new error diagnostics.
Startup and native AI are disabled for this isolated loader probe.

All1,734 tests, production build, installed waypoint/ownership regressions,
rendered casting (spellbook/radial/hotbar/animations/counterspell), and rendered
radial/body-bag regressions pass. Logs are `placeable-runtime-*-v*.txt` under
`backups/animations`. Existing production large-bundle warning remains.

This completes the concrete UTP adapter, not the full spell ecosystem.
CreateObject243 remains unbound; the UTM adapter is still unavailable. Existing
lower item property/equipment/load branches have their own evidence and limits.
Nonempty saved EffectList and ActionList, and valid saved Transition structs,
are explicitly rejected and reported by importing callers; they are not silently
dropped. Scoped transform sampling/drawing, material/texture/misc presentation
and non-creature animation presentation remain diagnosed limitations. UI name
projection is not full localized GetName/TLK precedence. OOM/unwinding, network
parity and campaign progress are not validated here.
