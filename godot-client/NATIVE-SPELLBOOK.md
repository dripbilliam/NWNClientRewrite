# Native spellbook and quickbar — partial migration

Godot now presents known spells, physical prepared slots, original spell icons,
class/level/metamagic choices, descriptions and nested spell-family choices.
Use **B** or the dock's Spellbook button. Select a leaf and Cast, double-click
it, or drag it to a shortcut. A family parent opens its children and cannot be
cast or assigned as a leaf. Preparing a variant prepares its shared parent.

Prepared rows show Ready versus Used/rest-required. Drag a known spell onto a
physical prepared slot, use Prepare for the next empty slot, or clear a selected
prepared spell. The original preparation/drop policy determines exchanges and
wire order. Requests reserve slots until actual replication or an explicit
timeout notice; they never edit the replicated spellbook or grant ready uses.

The native twelve-slot dock retains all **36** shortcut bindings across three
pages. **F1–F12** activates the displayed page; Shift and Ctrl temporarily select
pages two and three. Drag shortcuts to move them. Right-click now opens the
[assignment wheel](NATIVE-SHORTCUT-MENUS.md) and selects the slot for the explicit
Clear button. **Ctrl+Alt+F1/F2/F3** exposes the existing native
debug panels/FPS while live quickbar keys are active. Text entry keeps its keys;
WASD and middle orbit remain available with these menus open.

The book inherits native dragging, last-position storage and sibling priority.
Logical spell selection, description and list scroll positions survive ordinary
snapshot updates. Growing a family panel keeps its docked drag destination
visible. Images and captions occupy separate fixed rectangles, with independent
integer use counters. Closing a book rejects late snapshots; area/actor changes
retire handles and release controls/textures.

## Backend and ownership

`tools/spellbook-service.mjs` is a data-only adapter around the existing
`networkPreparationEntries`, `networkSpellUsesLeft`, spell-family helpers,
`preparationRequest`/`dropPreparation`, original feat/innate/item counters and
`NetworkSpellTargeting`. It resolves names/descriptions through the existing
NetworkText owner and original active tables. The normal source client and
production dist are unchanged; isolated staging remains v14.

Native drags carry a view ID and opaque entry ID. Cast/prepare/assign requests
revalidate actual actor identity, area/connection and the canonical spellbook
snapshot. Arbitrary bindings are not trusted. Async text/images and old controls
cannot overwrite replacement views. Shortcut assignments reuse the existing
session's original client-owned layout behavior and native wire request; that
layout update is distinct from server-owned spell availability and outcomes.
Slot moves send the destination before clearing an unchanged source.

Quickbar state is polled at most four times per second in independent work;
unchanged signatures do not rebuild native widgets. This work does not hold the
20 Hz authoritative pose stream or restart Three's rendering loop. This is an
ownership/scheduling boundary, not a measured full-scene performance claim.

## Evidence

- `reports/spellbook-node-regressions-v2.log`: **62 cases pass**: 10 new book/
  fixture cases, 9 action-service, 9 protocol and 8 evidence-gate cases, plus
  26 existing preparation/family/quickbar provider cases. They include shared
  family bindings, four authored children, spontaneous pools, domain/metamagic
  encoding, native exchange order, server-owned pending/timeout state, stale
  callbacks and no canonical actor mutation. The first batch's one failure was
  sandbox denial of a read-only installed module fixture; the admitted rerun
  passes all 62. Initial authored-test typos were corrected before acceptance.
- `reports/spellbook-ui-gpu-v2.json`: **22 native Vulkan UI checks** pass:
  known/prepared/family rows, typed drops, 36-slot page ownership, stale controls
  and icons, function keys/text focus/WASD independence, selection/description
  preservation, integer counters/readiness, and late closed-window rejection.
  Tall delayed authored images remain fixed for 90 real GUI frames; queue peak
  53,248 bytes, no script/layout errors. Headless v1's earlier 20 checks also
  passed. Authored UI callbacks are not claimed as physical human drag testing.
- **`reports/native-spellbook-local-v3.json`: all 49 actual local checks pass.**
  This includes the previous real NPC/dialogue/examine/radial flow, native
  wizard book/TLK/icon presentation, native drop-handler shortcut assignment,
  target mode and actual native ray clicks. Light uses replicate **2 → 1 → 0**.
  Clearing a physical used Light slot returns an actual null record; preparing
  returns spell 100 in the same physical slot with Ready=0. No ready use is
  fabricated. The report independently records the canonical before/after
  preparation records and typed cast observations.
- Actual original Protection from Alignment parent **321** exposes installed
  children **138/139**, not a hardcoded four-child list. Its child 139 is dragged
  to slot 34, targeted and cast; the server consumes the shared prepared parent
  **1 → 0**. Authored source/native checks separately cover a four-child family.
  The unmodified installed sample lacks family spells, so BookSmoke creates an
  **in-memory authored derivative** with one known/prepared parent. The original
  BIC remains read-only and its hash is recorded. The real server admits and
  replicates this character. All smoke modes now use an external temporary
  regression vault; no sample, user character or user vault is overwritten.
- v3 exits 0 and disconnects explicitly, with no native errors, renderer errors
  or diagnostics; GUI queue peak 24,576 bytes. Its family screenshot was visually
  inspected: both original child icons, shared counts, ready labels, scrollable
  lists and the unobscured dock are present. Tiny authored-room instantaneous
  FPS is not sustained complete captured-world acceptance.

Earlier local v1 passed 40 checks on the unchanged sample; v2 passed 48 including
the real family but its screenshot exposed delayed icons and dock overlap.
Final v3 waits for both child images and keeps the expanded book above the dock.
No failed or limited run is silently promoted to broader acceptance.

Run `join-local.ps1 -BookSmoke -Report <unused-name>.json` with the owned server
on the authored GodotGameplay fixture. It chooses only a regression character
and closes its own client. Normal `-AutoPlay` uses the original installed wizard
and normal application-vault behavior; it does not grant the fixture family.

## Remaining work

Full original spellbook/quickbar skins, bitmap fonts, sounds, secondary item
icons, all item/feat/skill/command assignment menus, original action-handler
coverage and native quickbar drag from radial/inventory remain partial.
Small viewports, deep-family stress, broad live spontaneous/domain/metamagic
cases, human input feel and reconnect persistence need broader acceptance.

Combat cue queues, casting/attack animation, blends/events, projectiles,
spell effects/audio and native AoE drawing are still separate incomplete work.
Inventory, other player windows, creation/level-up, full NUI and the remaining
migration ledger remain required. Full gameplay and sustained >=60 FPS on
complete moving captured/local scenes remain unaccepted. No Arelith connection
was made.

The subsequent [inventory shortcut milestone](NATIVE-INVENTORY.md#inventory-item-shortcuts)
adds owned-item dragging onto all three native quickbar pages and fixes item
icon metadata. Actual local assignment, shortcut-triggered equipment changes
and clearing pass;12 rendered synthetic drag/ownership checks,24 inventory,
22 spellbook and 40 backend regression checks pass. The earlier inventory-drag
gap above is resolved for default owned-item bindings; property-choice menus,
broader action handlers and full quickbar parity remain open.

[Native item powers](NATIVE-ITEM-POWERS.md) now have draggable wheel leaves,
original family/paged property bindings, charge disabling and secondary item
artwork. Authored GUI/backend tests and all 26 local v5 checks pass, including
real potion consumption, equipment activation and both clear actions. The
original game is preserved during functional tests. This does not complete assignment
menus, broader targeting or full shortcut parity.

The subsequent [native assignment menu](NATIVE-SHORTCUT-MENUS.md) implements
the original item/spell/feat/skill/ability/command categories, nested families,
More pages and Clear with private canonical selection. Missing skills are
queried from the real server and the character-sheet subscription restored.
All 34 local checks, seven rendered GUI checks and 69 backend tests pass;
broader category activation, persistence and full fidelity remain pending.
