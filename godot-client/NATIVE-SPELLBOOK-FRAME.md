# Native spellbook frame — scoped integration

The in-game spellbook now uses original main/memorization models instead of
the generic700×580 layout. This milestone is partial: full spellbook and full
UI parity remain unaccepted. General porting stays deferred.

## Original structure and active rules

`systems/native_spellbook_frame.gd` connects the
[recovered attachment plan](NATIVE-SPELLBOOK-RESEARCH.md) to the existing typed
spellbook/private-entry owner. Both main and separate memorization windows are
360×471. Eight class tabs, ten level tabs, independently expandable known
metamagic roots, ten prepared-level roots, source33px leaf links and nine-column
prepared rows use original models, hooks, fonts and per-pose geometry.

Class names/icons, spells, families, owned metamagic feats, level costs,
descriptions, domains and received slot contents come from the active resources
and character state. `spellbook_tree()` gives every visible branch a distinct
private entry ID/key, retaining each entry's own class, level and metamagic.
No slots or successful preparations are invented. Preparing a spell uses that
entry's destination level, rather than whichever page happens to be selected.
Cross-level/class destinations and retired views are rejected.

`CG_SPELLINFO` supplies the original help panel, title/edit/close geometry,
scrollbar and separate32px icon attachment. The original constructor1409c3680,
setup1409cd7b0 and destructor1409c4ef0 are retained in root
`backups/animations/rea-native-spellbook-description-v1.json`; all identify
original client SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The setup attaches a copied icon at `icon`, imports `EditBox`, `Title` and
`CloseButton`, and attaches the original scrollbar. Spell descriptions now
resolve **SpellDesc** from active `spells.2da`; the older generic Description
lookup returned empty help text.

The family chooser uses matching native artwork and scrollbars. Variant
shortcuts preserve the actual child spell binding. Main, memorization and
auxiliary windows remain movable/persistent and allow outside clicks, WASD and
middle-mouse camera input. Unrelated combat-state changes no longer rebuild
the spellbook and invalidate a drag.

Explicit Cast/Prepare/Clear commands remain in a separately styled Spell actions
utility opened by right click. Right click no longer simultaneously casts and
opens those commands. This utility is a replacement-only interaction, **not**
an accepted original gesture implementation. Original pickup, cancellation,
world-drop and right/double-click behavior still require comparison.

## Artwork queue ownership

Original icon-tab state combinations can exceed the shared128-job worker queue
in one frame. Previously a full queue permanently lost valid scrollbar/tab
requests. `native_item_icons.gd` now keeps accepted model jobs in a bounded4096
owner backlog and dispatches only as worker capacity opens. Duplicate requests
still share keys; texture overrides participate in both pose and geometry keys.
Retirement clears queued/dispatched ownership. Diagnostics include
`deferred_models` and `model_backlog_peak`. This does not change world rendering
or increase worker concurrency.

## Verification and rollback

`native-spellbook-frame-accepted-v1` passes47 graphical debugger checks using
original installed assets and isolated `SubViewport.push_input`, with no physical
pointer movement. It covers frame extents,8/10 tabs, multiple groups, private IDs,
nine-column wrapping, per-entry preparation, cross-level rejection, unchanged
authoritative state, original help text/icon, explicit commands without an
accidental cast, family-child shortcut assignment, stale callbacks, class
switching, retained independent positions,125percent proportions and outside
input. A two-worker-slot queue drains the GUI burst; a separate one-slot fixture
retires31 deferred jobs without publishing after close.

The final unchanged-source regression receipts are
`native-spellbook-regression-*-v2`: layout40, desktop41, record resizing55,
health148, health UI55, quickbar43, Examine62, store32, render retirement13 and
playability1314 checks. `native-spellbook-actions-v2` passes99 checks against
the owned original server at127.0.0.1:5125, including authoritative spellbook
casting, shortcut replication, preparation clearing/refilling, Rest and chat
feedback. There are no public connections and no workers remain after shutdown.
These live checks exercise the existing single-class sample; they do not prove
every new metamagic/domain/role scenario against a server.

Screenshots for help, prepared rows, family close and125percent UI are retained
under the accepted input run. The read-only audit is
`tools/audit-native-spellbook-frame.mjs`; its report records hashes for original
research, current source receipts, screenshots and the verified rollback
`backups/native-spellbook-frame-v1.zip`. Reports and private keys are excluded
from the source archive. Earlier failed fixture/readiness runs remain retained
and are not acceptance evidence.

## Remaining acceptance work

- Exact original input/drag pickup/drop-to-world/cancel, all keyboard shortcuts,
  help modal routing/close behavior and native class/level navigation arrows.
- Original sorting option, all disabled/selected/hover/pressed states, used-slot
  ghosting and metamagic visual treatment. Current used opacity is approximate.
- Source-matching class/role/spontaneous/domain/possession variants, preparation
  pending/refusal feedback and larger/localized names/overflow at every UI scale.
- Original-client side-by-side pixels/input and authoritative live checks for
  the newly grouped multi-class/metamagic/domain paths.
- Retirement of hidden unexpanded generic row objects and repeated-refresh
  allocation cost, if measurements show a need; current ownership is bounded by
  the received view but list reconstruction is still used.

The historical intermittent blood-pixel assertion in
`native-scrollbar-actions-accepted-v1` remains open. Passing this milestone's
99-action regression does not resolve that unrelated intermittent failure.

No narrow test count, source framing or rollback checkpoint marks the entire UI
goal complete.

The [prepared-slot transfer follow-up](NATIVE-SPELL-PREPARATION.md) now adds
original move/exchange ordering, pending/context ownership, canonical family
preparation and verified0.4 used alpha. Its58-input/106-local-action receipts
supersede this frame milestone's coverage for those specific paths. Exact
pickup/cancel/world-drop and the rest of the full-parity gaps remain open.
