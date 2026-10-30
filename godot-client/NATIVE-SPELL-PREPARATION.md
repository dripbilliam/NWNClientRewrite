# Original prepared-spell transfers and native pending ownership

This follow-up fixes two functional gaps in the
[native spellbook frame](NATIVE-SPELLBOOK-FRAME.md): prepared-slot drops copied
instead of moving/swapping, and preparation controls could issue repeated
writes while a prior request was awaiting the server. Full spellbook/UI parity
remains unaccepted. General porting stays deferred.

## Original policy and implementation

`systems/native_data/spell_preparation.gd` plans the original CSpellBox policy:

- A known-list source copies into the destination.
- A prepared source dropped into an occupied cell writes the displaced record
  back into the source **first**, then writes the dragged record into the
  destination. Both spells and their separate metamagic masks are retained.
- An empty-target move writes the destination, then clears the physical source
  through the original drag-completion policy. Dropping onto the same cell
  issues no writes.
- Both exchange writes deliberately use the **source domain flag**, matching
  the original's behavior even for the displaced record. Domain base levels
  use active metamagic cost and BYTE subtraction/wrapping. Do not replace this
  rule with a more intuitive normalization.
- Class/level compatibility, current source/destination content, private view
  ownership and actual received slot availability are checked before sending.
  Empty cells ignore residual metadata belonging to no spell. Family children
  prepare the owned parent while shortcut dragging retains the selected child.

Original drop1409c21d0, completion1409c2340, constructor1409c1e50,
SetSpell1409c2630 and Clear1409c1fc0 are the reference boundaries. The earlier
research retains constructor/set/clear/completion; root
`backups/animations/rea-native-spell-preparation-policy-v1.json` adds9 analyses
covering drop, release, tooltip, used alpha and drag capture/focus/key behavior.
All identify original client SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Used icon alpha is now the original **0.4**, recovered from1409c25f0.

## Authority and pending states

The planner changes no received spellbooks. All affected cells are claimed
before any request is emitted, preventing a duplicate/partial reservation.
Pending cells cannot start another drag or accept another preparation. The
prepare arrow skips pending empty cells. The separate utility's Prepare action
is disabled for physical slots, where self-preparation would do nothing.

Each write has a monotonically increasing private request ID. The existing
protocol bridge echoes that ID and world/actor context for preparation results;
it supplies no UI models or rendering. A successful send does **not** confirm
gameplay. A changed received slot releases its claim and the UI displays that
received state. This is not a separate claim that the requested exchange was
fully accepted. A correlated transport refusal releases only its own cell and
shows its failure text. Partial outcomes do not invent a rollback. After15s
without confirmation, a claim permits retry with explicit unconfirmed feedback.
World retirement removes old claims; stale replies cannot unlock new writes.

## Evidence and repeatable checks

`scripts/inspect-native-spell-preparation-drop.py` executes the pinned original
drop and completion instructions under the existing isolated Unicorn harness.
It captures GetType, SetSpell and Clear boundaries, with null icon pointers and
an idle original level-highlight restore. The384 observations cover known versus
prepared sources, occupied/empty targets, both source/destination domain flags,
multiple metamagic values and class indices0/7. They prove policy and write
order, not physical input, GPU appearance or all world/cancellation behavior.
The oracle is retained as
`backups/animations/native-spell-preparation-drop-observations-v1.json`.

Final unchanged-source debugger receipts use suffix **accepted-v2**:

| Receipt prefix `native-preparation-` | Checks | Scope |
| --- | ---: | --- |
| oracle |402|384 original policy observations plus pending/context/timeout/atomicity checks|
| input |58|Actual isolated viewport drags, empty residual metadata, used alpha, pending cells, transport acceptance, partial refusal, stale raw-state input, utility availability and prior spellbook frame checks|
| desktop |41|Existing native desktop integration|
| retirement |13|Existing GUI render ownership retirement|
| quickbar |43|Existing native quickbar input/artwork|
| playability |1314|Existing native gameplay regression corpus|
| server |106|Owned original server127.0.0.1:5125, including distinct-spell moves/exchanges|

The live probe discovers the actual received Light slot indices. It clears one
destination, moves the other preparation, copies a different known cantrip,
exchanges the distinct spells, and restores Light before the remaining checks.
Every outcome reads received server spellbooks and native UI projection; it
never edits the live character. The first candidate failed because its test
assumed Light occupied slots0/1. That failed evidence remains retained; the
accepted test uses received positions. Final public connections0, native exit0,
workers remaining0. Live mixed-domain/metamagic exchanges are still unaccepted.

Screenshots include the prepared view, help, family close and125percent layout.
`tools/audit-native-spell-preparation.mjs` checks current source pins, original
research/oracle hashes, screenshots, local outcomes and verified rollback
`backups/native-spell-preparation-v2.zip`. The source checkpoint includes the
authored oracle script and its inherited harness sources; reports and private
keys are excluded. Research/observations outside the archive are hashed by the
audit. Historical reports remain immutable source snapshots.
The v1 archive is retained as a candidate; its audit used an incorrect name for
the historical particle report. The corrected audit is checkpointed in v2.

## Remaining original gesture work

This milestone does not claim original click-to-pick-up/sticky cursor,
pickup-time clearing, cancel/focus loss, drag-to-world, complete shortcut/drop
routing, all tooltip/keyboard behavior, sounds, full state/role/domain variants
or an original-client side-by-side comparison. The retained drag-source analyses
show a squared-distance threshold16, a sticky-release path, focus-loss callback
flags0x44 and a native key0x12 release path. Their complete game/GUI context still
needs examination before changing those interactions. In particular, do not
assume dropping a spellbook icon into the world means casting it.

The native-styled Spell actions utility remains explicitly replacement-only;
it is not proof of original gesture parity. Other unfinished menus and the full
UI completion audit remain open. The historical intermittent blood-pixel
failure in `native-scrollbar-actions-accepted-v1` also remains open; passing the
current106-action regression does not resolve it.
