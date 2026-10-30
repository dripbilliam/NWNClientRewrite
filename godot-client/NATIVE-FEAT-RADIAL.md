# Native feat families, special attacks and shortcuts

2026-10-27. Native feat leaf/variant/callback rules and core Special Attacks
menus are implemented. Original-client/UI/combat parity remains partial under
[the migration goal](NATIVE-UI-COMBAT-MIGRATION-GOAL.md).

## Bugs corrected

- Family leaves used the child spell's FeatID as a new feat number with aux0.
  Native140991230 instead retains the parent feat and uses the child's FeatID
  upper WORD as its variant. Invalid child rows leave physical slot holes.
- Type4 shortcut assignment serializes a single signed INT. Keeping a separate
  auxiliary property lost it on the wire. Native family/Called Shot bindings now
  pack both WORDs into that INT and unpack them when activating it. Shortcut
  lookup masks the low WORD; variant names/icons use the selected child and
  remaining uses come from the received parent. Unlimited100 is hidden.
- The menu entry factory merged supplied state without overwrite. Its default
  disabled=false/uses=null silently discarded caller-supplied availability and
  counters. The explicit overwrite now preserves the supplied state.
- Feat activation previously sent generic feat input for compiled mode toggles.
  Native radial and hotbar paths now select mode requests. The hotbar validates
  its active feat metadata before mode dispatch, while the original radial
  callback's compiled mode cases precede its metadata query.
- Shortcut assignment now resets a previous NPC radial context to the controlled
  actor. Exhausted feats remain assignable without becoming castable.

`native_data/feat_radial.gd` reads current physical feat/spell rows and normal/
bonus ownership pools. It preserves successor ownership gaps, parent use/target
restrictions, physical variant slots, special Called Shot/familiar behavior and
the callback's self-retargeting auxiliary rules. Metadata is not cached against
the base install. Altering the active server's rows changes subsequent menus.
Successor cycles are rejected with bounded diagnostics instead of hanging.

## Special Attacks

Creature menus now expose Special Attacks in native slot3, and shortcut assignment
can reach that tree. The native builder's compiled IDs/slots are retained:

| Slot | Branch |
| --- | --- |
|0|Parry (mode2)|
|1/3|Called Shot arm/leg (feat5, aux65001/65000)|
|2|Power Attack mode|
|4|Knockdown, with the owned improved feat|
|5|Flurry mode|
|6|Disarm, with the owned improved feat|
|7|More Attacks: original physical slots for additional feats/modes, including Stunning Fist|

Names, icons where the original reads them, successors, family metadata and uses
come from the active tables/state. Compiled engine cases remain compiled cases,
including mode IDs and the original More Attacks icon overrides. The client does
not grant/spend feats, predict damage or set server modes locally.

## Original evidence and tests

Pinned NWN EE89.8193.37-17 x64 SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.

`../backups/animations/rea-native-feat-radial-port-v1.json` retains projected
complete function bodies/assembly and provider identity for leaf1409957a0,
variants140991230, callback140998520, Special Attacks140995090, its constructor
140992790 and More page140991720/3. Existing
`native-feat-radial-observations.json` captures1268 native leaf,216 variant and
504 selection cases. Its limits identify the intercepted boundaries; it is not
a native GPU or server simulation receipt. JS was consulted as reference only.

Final receipts under reports/, with current source hashes and no engine/lifetime
errors under normal-heap exception-trapping CDB:

| Run | Checks | Scope |
| --- | ---: | --- |
|native-feat-radial-oracle-final-v3|2000|1988 retained original observations plus physical table mutation, parent use/target restrictions, signed packing and cycle cases|
|native-feat-ui-routing-final-v3|24|Actual native desktop/menu/shortcut flow to exact typed requests; special-attack slots, Parry/mode routing, child art/counts, assignment and invalid metadata|
|native-feat-playability-final-v2|1314|Existing native gameplay/UI rule regressions|
|native-feat-radial-drag-final-v3|14|Existing real Godot viewport drag/drop and private binding identity|
|native-feat-facing-regression-v2|15|Existing rendered target-facing integration|
|native-feat-correction-regression-v2|32|Existing private correction playback, priorities and gait restoration|

Total3399 checks. These correctness checks do not establish a performance gain.

`native-feat-family-server-final-v2`: owned unchanged original server on
loopback5125,18 checks pass, Godot capped at30 FPS without focus, original Druid BIC.
The only uploaded-character change remains the existing test XP adjustment;
ownership, family rules, variant behavior and resulting model are original data.
The test reaches the actual private radial leaf, assigns its payload, receives
the shortcut back from the server, activates the actual quickbar control and
waits for authoritative use and appearance changes. It then waits for that new
native body and drives an ordinary server walk beyond one original clip length.
The running original client and other owned servers are preserved. No public
connection, fabricated replication, forced appearance or animation-pose edit.

Both retained final server results demonstrate parent338/aux1008 packed66060626,
uses5→4 and appearance2→15. Shaped cwalk remained active across a full cycle,
advanced its actual model clock and changed18 local parts without missing clips.
The final receipt repeats the scenario against final source with host/native
success, unchanged source, zero public connections/exceptions, acknowledged
finish and zero remaining workers. High auxiliaries
65000/65001 and negative packed INTs have native-oracle/desktop coverage; the
original Druid's positive1008 auxiliary is the live-server case, not proof of
every custom server variant or all negative packed assignments.

Failed receipts remain retained: oracle-v1's missing-row fixture used float JSON
IDs in a strict integer membership test; normalization fixes the fixture without
changing expectations. UI-routing-v1 found the real merge/availability bug.
Family-probe-compile-v1 needed an explicit integer actor ID before the graphical
test could run. Accepted receipts have no waived script/engine errors.

## Remaining work

Native class/domain ability grouping and OnMenu tables, all context/role roots,
emotes/skills and broader possession/associate behavior remain. Mode captions
are neutral feat labels; exact active-mode Cancel labels and defensive-stance
special presentation need their actual live mode-state source. The helper's
stance branch is covered by retained observations, but the desktop does not
invent that state when it has not been supplied.

Special-attack effects/damage/death, more shaped/weapon bodies and paired original
client timing still need broader live acceptance. The existing undisclosed-
maximum-HP blood-effect failure remains unresolved. A successful family shortcut
and one shaped walk do not establish all combat ready. Other window artwork,
native radial previews/preferences/rubber-band and complete gameplay parity are
still tracked by the full goal.
