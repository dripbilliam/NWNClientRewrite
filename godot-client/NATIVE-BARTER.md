# Native player barter — scoped original-server acceptance

The later [Offer/Accept artwork correction](NATIVE-BARTER-BUTTON-STATES.md)
fixes identical checked/unchecked button pixels and verifies real peer
acceptance/retraction on the owned original server. Evidence below describes
this earlier milestone's historical source.

The replacement now decodes the original barter start/close/lock/accept messages,
tracks both offer repositories and constructs the trade window in native Godot
from active `INGAME_BARTER.gui` and MDL resources. A real two-player original-server
check now verifies item/currency exchange and cancellation refunds in both roles.
Mixed original/replacement client acceptance and wider content remain open;
this does not complete the active UI/combat migration goal.

## Original behavior recovered

Original NWN EE89.8193.37-17 x64 SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Read-only evidence: `backups/animations/rea-native-barter-v1.json`,
`rea-native-barter-controls-v1.json`, and `native-barter-wire-observations-v1.json`.

- Client senders1407ba070..1407ba480 and server443810 use message35: start1,
  close3, add5, remove6, lock7, accept9, window12 and move13. Server replies are
  start2, close4, lock8, accept10 and reject11.
- Lock/accept replies carry the initiating-side BOOL followed by that side's new
  value. They do not carry two independent participant-state flags. Client
  handlers1407701a0/1407704b0 compare the first BOOL with the local initiator role.
- Original inventory dispatcher1407b3c90 and reader1407b4620 bind **B to local
  PlayerItems** at panel+2d8 and **A to remote BarterItems** at panel+4b0.
  Original GUI importer14097dc10 confirms those tags. Both grids are3×10, with
  the same33px cells/lower-left item anchors as the ordinary inventory.
- Original other-player root menu140993790 places Barter at slot7. Social
  submenu constructors140992540/140994b40 use slot6 instead. The native root
  chooses Barter for disclosed other players; NPC roots retain Talk.
- `CGuiCheckbox::SetChecked1401e5ae0` selects `checkedup`/`uncheckedup`.
  Original checkbox models also contain checked/unchecked down and disabled
  poses. A latched Godot toggle must not remain in the physical-down pose.
  The native painter tracks physical press separately from server check state.

`scripts/inspect-native-barter-wire.py` executes288 unchanged original request/
reply senders and scalar/ID writers under the existing read-only emulator.
Only transport is captured.128 client and16 server cases use the replacement's
native message format and match the codecs. The other cases exercise the
original's alternate format. This is codec evidence, not a real trade.

## Native ownership and actions

`src/network_barter.js` contains protocol serialization/decoding and client proxy
state only. `NetworkWorld` binds offer owners from received trade participants,
keeps one canonical item ID and retires trade state on close/control/area changes.
`NetworkGameSession.barterInput` revalidates actor/area/generation/trade identity,
item membership and lock state. Sending a request changes no balance, ownership,
lock or acceptance flag. Gold offers use the original placement-bearing message8/1
variant, tied to the current unlocked trade and partner.

`native_barter.gd`, `native_barter_view.gd`, `native_barter_grid.gd` and
`native_barter_slot.gd` own presentation and input. Native workers read original
GUI/models. The shared native artwork painter preserves pose bounds and keeps
captions above artwork. Original portrait meshes/UVs replace `gui_replace01`
with the disclosed portrait resource. Windows drag/raise/save through the normal
native window owner. WASD handling remains outside these pointer controls.

Own lock and acceptance remain pending until the corresponding received state
revision is observed. An older in-flight header cannot roll flags back. Offer
add/move/remove stays pending until canonical server item/membership data changes
or a real rejection arrives. Ordinary inventory drags add carried items;
offer-to-backpack drags remove them. Remote offers are read-only and can be
examined through the original eye action/right-click radial. Gold uses the shared
native amount/drag controls. No JS rendering or presentation models are introduced.

## Current scoped evidence

- `network-barter-native.test.js`: original packets, both participant roles,
  B/A ownership, canonical IDs, independent flags and session stale/lock guards.
  Existing gold/rejection packet tests also pass.
- `native-barter-playability-v1`:1314 native gameplay routing/rules checks.
- `native-barter-ui-v3`:25 graphical checks with original models/fonts/icons and
  actual injected GUI events: own/other locks, acceptance, state-revision gating,
  offer removal, remote examination, gold placement, saved dragging and both
  initiator/recipient roles. Native exit0, unchanged source, no caught exception
  or script/lifetime errors. The locked-window PNG was inspected.

These graphical checks use authored server snapshots in the existing isolated,
manually notified SubViewport. They do not move the physical cursor or take focus,
and do not by themselves prove real multiplayer trade completion.

The owned-server harness uses the unchanged original server on127.0.0.1:5125,
the native Godot client and a second protocol-only participant. It never connects
publicly, fabricates a license key, edits a live balance or runs local trade rules.
The helper's explicitly test-only status is separate from the native game world;
other-player private stats are not injected into normal gameplay objects.

Failed receipts remain retained. GUI-v1 had an authored fixture syntax error;
GUI-v2 omitted mouse-motion relative displacement and checked backpack widgets
before their next presentation frame. GUI-v3 supplies complete events and waits
for that frame without changing the membership assertions. Admission-v1 omitted
current-world scope on the private test command, so the host rejected it before
starting the partner. Admission-v2 corrects that envelope and is under test.

## Real local-server exchange and visual follow-up

`native-barter-exchange-final-v2` checks two real authenticated participants on
the unchanged original server at127.0.0.1:5125. The main participant uses native
Godot controls; the other is a protocol-only test helper, with no local trade
rules. Its private test status is separate from the gameplay object registry.
The48 checks cover original radial start, non-stacking item offers and movement,
remote item examination/read-only input, amount-dialog gold placement, both
server locks, one-sided acceptance without delivery, two-sided completion,
canonical item exchange, exact currency credit, peer-initiated recipient role,
and cancellation with original item/currency refunds. Sources stay pinned,
workers retire, native exit0, debugger armed with no caught native exception,
and no public connection. `native-barter-gold-regression-v2` preserves the85-check
inventory/gold/casting/level-up/combat baseline.

The user authorized both existing keys for local participants. Windows DPAPI
files live only under ignored`runtime-logs`; credentials travel through private
pipes/startup stdin, never arguments, environment, evidence or source archives.
Action tests read their override key without replacing the saved main login.
The helper waits for actual player/inventory replication before readiness and
resolves participants through disclosed player-list identities.

`native-barter-ui-v5` has28 graphical input/lifetime checks. Barter titles and
portraits merge only disclosed player-list presentation data, without mutating
received object state. Name and numeric/resource portrait changes invalidate
presentation; missing portrait sizes use native catalog fallback. Original
portrait model UVs retain the authored crop. The screenshot was inspected.
The visible model-raster audit covers21 inventory/barter rectangles; maximum
axis-scale disagreement is below0.000001. This does not prove all source UVs or
other menus correct. The user's stretched-assets report remains an open visual
acceptance item. Hidden engine-created scroll decorations are outside this
visible artwork audit.

Other current receipts: `native-barter-playability-final-v1`1314 checks,
`native-barter-frame-regression-v1`157 graphical checks,
`native-barter-art-bindings-v1`8 checks, and
`native-barter-protocol-final-v2.tap`62 passing protocol/session checks.
The initial protocol run's one failure was sandbox access to installed modules;
the authorized read-only rerun passed.

Earlier failed receipts remain. Admission-v4 received login rejection9 using
the prior test credential; v5 exposed premature readiness; v6 verified lock and
cancel. Exchange-v1/v3 delivered correct items but the test compared JSON float
IDs with native integer IDs; v2 exposed inventory-readiness timing. V4 completed
all48 predicates but its polling helper accessed a temporarily null location,
so engine-error gating correctly rejected the run. The helper now treats null
as undisclosed membership. GUI-v4's geometry audit incorrectly included hidden
engine scroll decorations; v5 audits visible artwork. These failed receipts are
not acceptance evidence.

Rollback: `backups/native-inventory-gold-v1.zip` before;
`backups/native-player-barter-v1.zip` after, read back and source verified.
`reports/native-barter-acceptance-v1.json` indexes current pins and the archive.
Remaining: mixed original/replacement client trade, range/area/control changes,
stack merging, full rejection/cancellation feedback, custom-resource variants,
store framing and the remaining original gameplay windows. Runtime snapshot
`full_barter_acceptance:false` deliberately includes those wider open cases.
